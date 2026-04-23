import SwiftUI

struct SessionsTab: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !store.activeSessions.isEmpty {
                    activeSessionsSection
                }
                recentSection
            }
            .padding(16)
        }
    }

    private var activeSessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 5) {
                Circle()
                    .fill(.green)
                    .frame(width: 6, height: 6)
                    .overlay(
                        Circle()
                            .fill(.green.opacity(0.4))
                            .frame(width: 10, height: 10)
                    )
                Text("Active (\(store.activeSessions.count))")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }

            ForEach(store.activeSessions.sorted(by: { $0.startedAt > $1.startedAt })) { session in
                activeSessionRow(session)
            }
        }
    }

    private func activeSessionRow(_ session: ActiveSession) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 10))
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.name ?? session.projectName)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("v\(session.version)")
                    Text("·")
                    Text(Formatting.duration(session.duration))
                    Text("·")
                    Text("PID \(session.pid)")
                }
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.4))
            }

            Spacer()
        }
        .padding(8)
        .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.green.opacity(0.2)))
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Recent Conversations")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))

            if store.conversations.isEmpty {
                Text("No conversation data yet")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
            } else {
                ForEach(store.conversations.prefix(20)) { convo in
                    SessionRowView(conversation: convo)
                    if convo.id != store.conversations.prefix(20).last?.id {
                        Divider().opacity(0.3)
                    }
                }
            }
        }
    }
}
