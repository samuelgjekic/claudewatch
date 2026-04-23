import Foundation
import SwiftUI
import Combine

@MainActor
class UsageStore: ObservableObject {
    @Published var selectedTab: PopoverTab = .overview
    @Published var showingSettings = false
    @Published var isLoading = false
    @Published var lastUpdated: Date?
    @Published var errorMessage: String?

    @Published var rateLimits: RateLimitData = .empty
    @Published var statsCache: StatsCache?
    @Published var activeSessions: [ActiveSession] = []
    @Published var conversations: [ConversationSummary] = []
    @Published var menuBarDisplay: MenuBarDisplay = .session

    let auth = AuthService()

    private let defaults = UserDefaults.standard
    private let dataService = LocalDataService()
    private let rateLimitService = RateLimitService()
    private var refreshTimer: Timer?
    private var sessionTimer: Timer?
    private var hasStarted = false
    private var cancellables = Set<AnyCancellable>()

    init() {
        auth.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        auth.$isLoggedIn
            .removeDuplicates()
            .filter { $0 }
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in await self.refresh() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Settings

    func saveMenuBarDisplay(_ mode: MenuBarDisplay) {
        menuBarDisplay = mode
        defaults.set(mode.rawValue, forKey: "menuBarDisplay")
    }

    private func loadMenuBarDisplay() {
        menuBarDisplay = MenuBarDisplay(rawValue: defaults.string(forKey: "menuBarDisplay") ?? "") ?? .session
    }

    // MARK: - Menu bar

    var menuBarIconName: String {
        guard auth.isLoggedIn else { return "battery.0percent" }
        let pct: Int
        switch menuBarDisplay {
        case .session: pct = rateLimits.sessionRemaining
        case .weekly: pct = rateLimits.weeklyRemaining
        case .both: pct = min(rateLimits.sessionRemaining, rateLimits.weeklyRemaining)
        case .sonnet: pct = 100 - rateLimits.overagePercent
        }
        switch pct {
        case 76...100: return "battery.100percent"
        case 51...75: return "battery.75percent"
        case 26...50: return "battery.50percent"
        case 1...25: return "battery.25percent"
        default: return "battery.0percent"
        }
    }

    var menuBarText: String {
        guard auth.isLoggedIn else { return "--" }
        switch menuBarDisplay {
        case .session: return "\(rateLimits.sessionPercent)%"
        case .weekly: return "\(rateLimits.weeklyPercent)%"
        case .both: return "S:\(rateLimits.sessionPercent) W:\(rateLimits.weeklyPercent)"
        case .sonnet: return "\(rateLimits.overagePercent)%"
        }
    }

    var menuBarColor: Color {
        guard auth.isLoggedIn else { return .gray }
        let used: Double
        switch menuBarDisplay {
        case .session: used = rateLimits.sessionUtilization
        case .weekly: used = rateLimits.weeklyUtilization
        case .both: used = max(rateLimits.sessionUtilization, rateLimits.weeklyUtilization)
        case .sonnet: used = rateLimits.overageUtilization
        }
        switch used {
        case 0..<0.4: return .green
        case 0.4..<0.7: return .blue
        case 0.7..<0.9: return .orange
        default: return .red
        }
    }

    var sessionIconName: String {
        guard auth.isLoggedIn else { return "battery.0percent" }
        return batteryIcon(for: rateLimits.sessionRemaining)
    }

    var weeklyIconName: String {
        guard auth.isLoggedIn else { return "battery.0percent" }
        return batteryIcon(for: rateLimits.weeklyRemaining)
    }

    private func batteryIcon(for remaining: Int) -> String {
        switch remaining {
        case 76...100: return "battery.100percent"
        case 51...75: return "battery.75percent"
        case 26...50: return "battery.50percent"
        case 1...25: return "battery.25percent"
        default: return "battery.0percent"
        }
    }

    // MARK: - Helpers

    var daysUsingClaude: Int {
        guard let cache = statsCache else { return 0 }
        return Formatting.daysAgo(from: String(cache.firstSessionDate.prefix(10))) ?? 0
    }

    var statsAge: String { statsCache?.lastComputedDate ?? "unknown" }

    // MARK: - Lifecycle

    func ensureStarted() {
        guard !hasStarted else { return }
        hasStarted = true
        loadMenuBarDisplay()
        auth.loadStoredCredentials()
        startTimers()
    }

    // MARK: - Data loading

    func refresh() async {
        isLoading = true
        errorMessage = nil

        do {
            if let orgId = auth.organizationId, auth.isLoggedIn {
                let limits = try await rateLimitService.fetchUsage(organizationId: orgId)
                self.rateLimits = limits
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }

        let cache = try? await dataService.loadStatsCache()
        let sessions = (try? await dataService.loadActiveSessions()) ?? []
        let history = (try? await dataService.loadHistory(maxLines: 3000)) ?? []
        let convos = await dataService.buildConversations(
            from: history,
            totalMessages: cache?.totalMessages ?? history.count
        )

        self.statsCache = cache
        self.activeSessions = sessions
        self.conversations = Array(convos.prefix(30))
        self.lastUpdated = Date()
        self.isLoading = false
    }

    func refreshSessions() async {
        if let sessions = try? await dataService.loadActiveSessions() {
            self.activeSessions = sessions
        }
    }

    // MARK: - Timers

    private func startTimers() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refresh() }
        }
        sessionTimer?.invalidate()
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.refreshSessions() }
        }
        Task { await refresh() }
    }
}
