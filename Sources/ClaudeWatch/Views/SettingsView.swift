import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    @State private var selectedMenuBarDisplay: MenuBarDisplay = .session

    var body: some View {
        VStack(spacing: 14) {
            header

            ScrollView {
                VStack(spacing: 12) {
                    accountSection
                    menuBarSection
                    dataInfoSection
                }
            }

            actionButtons
        }
        .padding(16)
        .frame(width: 370)
        .background(Color(white: 0.08))
        .onAppear { selectedMenuBarDisplay = store.menuBarDisplay }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 5) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.5))
                Text("Settings")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Spacer()
            Button(action: { withAnimation { store.showingSettings = false } }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Account", systemImage: "person.crop.circle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    if let email = store.auth.userEmail {
                        Text(email)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    if let org = store.auth.orgName {
                        Text(org)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()

                Button(action: {
                    store.auth.logout()
                }) {
                    Text("Disconnect")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.2)))
    }

    private var menuBarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Menu Bar Display", systemImage: "menubar.rectangle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            Picker("", selection: $selectedMenuBarDisplay) {
                ForEach(MenuBarDisplay.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)

            Text(menuBarDescription)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(10)
        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.2)))
    }

    private var menuBarDescription: String {
        switch selectedMenuBarDisplay {
        case .session: return "Shows current session (5h window) usage in the menu bar"
        case .weekly: return "Shows current week (7d window) usage in the menu bar"
        case .both: return "Shows both session and weekly usage in the menu bar"
        case .sonnet: return "Shows Sonnet-only overage usage in the menu bar"
        }
    }

    private var dataInfoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Data Source", systemImage: "internaldrive")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            VStack(alignment: .leading, spacing: 4) {
                infoRow("Rate limits", "Anthropic API (live)")
                infoRow("Local stats", "~/.claude/stats-cache.json")
                infoRow("Stats computed", store.statsAge)
                infoRow("Total sessions", "\(store.statsCache?.totalSessions ?? 0)")
                infoRow("Total messages", "\(store.statsCache?.totalMessages ?? 0)")
                infoRow("Active sessions", "\(store.activeSessions.count)")
            }
        }
        .padding(10)
        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(white: 0.2)))
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    private var actionButtons: some View {
        HStack {
            Button("Cancel") {
                withAnimation { store.showingSettings = false }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(0.5))

            Spacer()

            Button(action: save) {
                Text("Save")
                    .font(.system(size: 11, weight: .medium))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .controlSize(.small)
        }
    }

    private func save() {
        store.saveMenuBarDisplay(selectedMenuBarDisplay)
        withAnimation { store.showingSettings = false }
    }
}
