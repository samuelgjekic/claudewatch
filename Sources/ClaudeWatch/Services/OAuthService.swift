import Foundation
import AppKit
import WebKit

@MainActor
class AuthService: NSObject, ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoggingIn = false
    @Published var loginError: String?
    @Published var userEmail: String?
    @Published var orgName: String?

    private let defaults = UserDefaults.standard
    private var loginWebView: WKWebView?
    private var loginWindowController: NSWindowController?
    private var cookiePollTimer: Timer?
    private var hasCapturedSession = false
    private var popupWebView: WKWebView?

    var sessionKey: String? { defaults.string(forKey: "claudeSessionKey") }
    var organizationId: String? { defaults.string(forKey: "claudeOrgId") }

    func loadStoredCredentials() {
        if let _ = defaults.string(forKey: "claudeSessionKey"),
           let _ = defaults.string(forKey: "claudeOrgId") {
            isLoggedIn = true
            userEmail = defaults.string(forKey: "claudeEmail")
            orgName = defaults.string(forKey: "claudeOrgName")
        }
    }

    func startLogin() {
        isLoggingIn = true
        loginError = nil
        hasCapturedSession = false

        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.applicationNameForUserAgent = "Version/18.3 Safari/605.1.15"

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 480, height: 640), configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        self.loginWebView = webView

        config.websiteDataStore.httpCookieStore.add(self)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 640),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Sign in to Claude"
        window.contentView = webView
        window.center()
        window.delegate = self
        window.isReleasedWhenClosed = false

        NSApp.setActivationPolicy(.regular)
        let controller = NSWindowController(window: window)
        controller.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.loginWindowController = controller

        webView.load(URLRequest(url: URL(string: "https://claude.ai/login")!))

        startCookiePolling(webView: webView)
    }

    func cancelLogin() {
        stopLoginWindow()
        isLoggingIn = false
    }

    func logout() {
        defaults.removeObject(forKey: "claudeSessionKey")
        defaults.removeObject(forKey: "claudeOrgId")
        defaults.removeObject(forKey: "claudeEmail")
        defaults.removeObject(forKey: "claudeOrgName")
        defaults.removeObject(forKey: "claudeCookieHeader")
        isLoggedIn = false
        userEmail = nil
        orgName = nil
    }

    // MARK: - Cookie polling

    private static let debugLog = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/claudewatch-debug.log")

    private func log(_ msg: String) {
        let line = "[\(Date())] \(msg)\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: Self.debugLog.path) {
                if let fh = try? FileHandle(forWritingTo: Self.debugLog) {
                    fh.seekToEndOfFile(); fh.write(data); fh.closeFile()
                }
            } else {
                try? data.write(to: Self.debugLog)
            }
        }
    }

    private func startCookiePolling(webView: WKWebView) {
        log("Cookie polling started")
        cookiePollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self, weak webView] _ in
            guard let self, let webView, !self.hasCapturedSession else { return }

            // Method 1: Check cookie store directly (catches httpOnly cookies)
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                guard !self.hasCapturedSession else { return }
                let all = cookies.map { "\($0.name)@\($0.domain)" }.joined(separator: ", ")
                self.log("Cookie store poll: \(cookies.count) cookies: \(all)")

                let claudeCookies = cookies.filter { $0.domain.contains("claude.ai") }
                if let session = claudeCookies.first(where: { $0.name == "sessionKey" }) {
                    self.log("Found sessionKey via cookie store!")
                    let header = claudeCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
                    self.hasCapturedSession = true
                    self.cookiePollTimer?.invalidate()
                    self.cookiePollTimer = nil
                    Task { @MainActor in
                        await self.finishLogin(sessionKey: session.value, cookieHeader: header)
                    }
                    return
                }
            }

            // Method 2: Check JS document.cookie (non-httpOnly cookies)
            webView.evaluateJavaScript("document.cookie") { result, _ in
                guard let cookieString = result as? String, !self.hasCapturedSession else { return }
                if let range = cookieString.range(of: "sessionKey=") {
                    let start = cookieString[range.upperBound...]
                    let value = String(start.prefix(while: { $0 != ";" }))
                    if !value.isEmpty {
                        self.log("Found sessionKey via JS!")
                        self.hasCapturedSession = true
                        self.cookiePollTimer?.invalidate()
                        self.cookiePollTimer = nil
                        Task { @MainActor in
                            await self.finishLogin(sessionKey: value, cookieHeader: cookieString)
                        }
                    }
                }
            }

            // Method 3: Check URL — if we navigated away from /login, login likely succeeded
            if let url = webView.url {
                self.log("Current URL: \(url.absoluteString)")
                if url.host?.contains("claude.ai") == true && !url.path.contains("login") && url.path != "/" {
                    self.log("Detected navigation away from login page")
                }
            }
        }
    }

    private func finishLogin(sessionKey: String, cookieHeader: String) async {
        log("finishLogin called with sessionKey length: \(sessionKey.count)")
        defaults.set(sessionKey, forKey: "claudeSessionKey")
        defaults.set(cookieHeader, forKey: "claudeCookieHeader")

        do {
            let request = Self.makeRequest(path: "/api/organizations")
            log("Fetching organizations...")
            let (data, response) = try await Self.apiSession.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let body = String(data: data, encoding: .utf8) ?? ""
            log("Organizations response: \(status) body: \(String(body.prefix(500)))")
            guard status == 200 else {
                throw AuthError.orgFetchFailed(status)
            }

            struct Org: Codable {
                let uuid: String
                let name: String?
                let email_address: String?
            }
            let orgs = try JSONDecoder().decode([Org].self, from: data)
            log("Found \(orgs.count) orgs: \(orgs.map { $0.uuid })")

            var validOrg: Org?
            var fallbackOrg: Org?
            for org in orgs {
                let probe = Self.makeRequest(path: "/api/organizations/\(org.uuid)/usage")
                log("Probing usage for org \(org.uuid) (\(org.name ?? "unnamed"))...")
                if let (probeData, resp) = try? await Self.apiSession.data(for: probe),
                   let h = resp as? HTTPURLResponse {
                    let probeBody = String(data: probeData, encoding: .utf8) ?? ""
                    log("Probe \(org.name ?? "unnamed"): \(h.statusCode) body: \(String(probeBody.prefix(300)))")
                    if (200...299).contains(h.statusCode) {
                        if fallbackOrg == nil { fallbackOrg = org }
                        if let json = try? JSONSerialization.jsonObject(with: probeData) as? [String: Any],
                           let fiveHour = json["five_hour"] as? [String: Any],
                           let util = fiveHour["utilization"] as? Double,
                           util > 0 {
                            validOrg = org
                            break
                        }
                    }
                }
            }
            if validOrg == nil { validOrg = fallbackOrg }

            guard let org = validOrg else {
                log("No org with usage access found")
                loginError = "No organization with usage access found."
                isLoggingIn = false
                stopLoginWindow()
                return
            }

            log("Using org: \(org.uuid) email: \(org.email_address ?? "nil")")
            defaults.set(org.uuid, forKey: "claudeOrgId")
            if let email = org.email_address {
                defaults.set(email, forKey: "claudeEmail")
                userEmail = email
            }
            defaults.set(org.name ?? "Claude", forKey: "claudeOrgName")
            orgName = org.name

            isLoggedIn = true
            isLoggingIn = false
            log("Login complete!")
            stopLoginWindow()
        } catch {
            log("finishLogin error: \(error)")
            loginError = error.localizedDescription
            isLoggingIn = false
            stopLoginWindow()
        }
    }

    private func stopLoginWindow() {
        NSApp.setActivationPolicy(.accessory)
        cookiePollTimer?.invalidate()
        cookiePollTimer = nil
        popupWebView?.removeFromSuperview()
        popupWebView = nil
        loginWebView?.stopLoading()
        if let store = loginWebView?.configuration.websiteDataStore.httpCookieStore {
            store.remove(self)
        }
        loginWebView = nil
        loginWindowController?.close()
        loginWindowController = nil
    }

    // MARK: - API session (ephemeral, no cookie storage — cookies set explicitly)

    static let apiSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.timeoutIntervalForRequest = 30
        return URLSession(configuration: config)
    }()

    nonisolated static func makeRequest(path: String) -> URLRequest {
        let url = URL(string: "https://claude.ai\(path)")!
        var request = URLRequest(url: url)
        if let key = UserDefaults.standard.string(forKey: "claudeSessionKey") {
            request.setValue("sessionKey=\(key)", forHTTPHeaderField: "Cookie")
        }
        request.setValue("web_claude_ai", forHTTPHeaderField: "anthropic-client-platform")
        request.setValue("1.0.0", forHTTPHeaderField: "anthropic-client-version")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("empty", forHTTPHeaderField: "sec-fetch-dest")
        request.setValue("cors", forHTTPHeaderField: "sec-fetch-mode")
        request.setValue("same-origin", forHTTPHeaderField: "sec-fetch-site")
        request.setValue("https://claude.ai", forHTTPHeaderField: "origin")
        request.setValue("https://claude.ai/settings/usage", forHTTPHeaderField: "referer")
        return request
    }

    nonisolated static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.3 Safari/605.1.15"

    enum AuthError: LocalizedError {
        case orgFetchFailed(Int)
        var errorDescription: String? {
            switch self {
            case .orgFetchFailed(let code): return "Failed to fetch organizations (\(code))"
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension AuthService: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        if url.scheme == "about" { decisionHandler(.allow); return }
        guard let host = url.host else { decisionHandler(.cancel); return }

        log("Navigation: \(webView == popupWebView ? "POPUP" : "MAIN") → \(url.absoluteString)")

        // If the popup is navigating back to claude.ai, remove it and let the main webview handle things
        if webView == popupWebView && host.contains("claude.ai") {
            log("Popup redirecting to claude.ai — removing popup")
            decisionHandler(.cancel)
            DispatchQueue.main.async {
                self.popupWebView?.removeFromSuperview()
                self.popupWebView = nil
                self.loginWebView?.load(URLRequest(url: url))
            }
            return
        }

        let allowed = [
            "claude.ai", "anthropic.com",
            "google", "gstatic.com", "googleapis.com",
            "googleusercontent.com", "youtube.com",
            "appleid.apple.com", "icloud.com",
            "challenges.cloudflare.com"
        ]
        let isGoogle = host.hasPrefix("accounts.google.") || host.hasPrefix("www.google.")
        if isGoogle || allowed.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) {
            decisionHandler(.allow)
        } else {
            log("Blocked navigation to: \(host)")
            decisionHandler(.cancel)
        }
    }
}

// MARK: - WKUIDelegate

extension AuthService: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        log("Popup requested for: \(navigationAction.request.url?.absoluteString ?? "nil")")
        let popup = WKWebView(frame: webView.bounds, configuration: configuration)
        popup.navigationDelegate = self
        popup.uiDelegate = self
        popup.autoresizingMask = [.width, .height]
        webView.addSubview(popup)
        self.popupWebView = popup
        return popup
    }

    func webViewDidClose(_ webView: WKWebView) {
        log("webViewDidClose called")
        if webView == popupWebView {
            popupWebView?.removeFromSuperview()
            popupWebView = nil
        }
    }
}

// MARK: - WKHTTPCookieStoreObserver

extension AuthService: WKHTTPCookieStoreObserver {
    func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        guard !hasCapturedSession else { return }
        cookieStore.getAllCookies { [weak self] cookies in
            guard let self, !self.hasCapturedSession else { return }
            let claudeCookies = cookies.filter {
                $0.domain == "claude.ai" || $0.domain == ".claude.ai" || $0.domain.hasSuffix(".claude.ai")
            }
            guard let session = claudeCookies.first(where: { $0.name == "sessionKey" && $0.isSecure && $0.path == "/" }) else { return }

            self.hasCapturedSession = true
            self.cookiePollTimer?.invalidate()
            self.cookiePollTimer = nil
            let header = claudeCookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")

            Task { @MainActor in
                await self.finishLogin(sessionKey: session.value, cookieHeader: header)
            }
        }
    }
}

// MARK: - NSWindowDelegate

extension AuthService: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        if !isLoggedIn {
            isLoggingIn = false
            hasCapturedSession = false
        }
        cookiePollTimer?.invalidate()
        cookiePollTimer = nil
        popupWebView?.removeFromSuperview()
        popupWebView = nil
        loginWebView?.stopLoading()
        loginWebView = nil
    }
}
