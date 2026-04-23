import SwiftUI

@main
struct ClaudeWatchApp: App {
    @StateObject private var store = UsageStore()

    var body: some Scene {
        MenuBarExtra {
            MainPopoverView(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        Image(nsImage: BatteryIconRenderer.makeMenuBarImage(
            mode: store.menuBarDisplay.rawValue,
            sessionPercent: store.rateLimits.sessionPercent,
            weeklyPercent: store.rateLimits.weeklyPercent,
            sonnetPercent: store.rateLimits.overagePercent
        ))
        .onAppear {
            store.ensureStarted()
        }
    }
}
