import SwiftUI

struct OverviewTab: View {
    @ObservedObject var store: UsageStore

    private var limits: RateLimitData { store.rateLimits }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                usageBar("Current Session", limits.sessionUtilization, limits.sessionReset)
                usageBar("Current Week", limits.weeklyUtilization, limits.weeklyReset)
                if limits.overageUtilization > 0 || limits.hasOverageTier {
                    usageBar("Sonnet Only", limits.overageUtilization, limits.overageReset)
                }

                if limits.fallbackAvailable {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.system(size: 10))
                        Text("Fallback model available")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.cyan)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(.cyan.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }

                Divider().padding(.vertical, 2)

                sessionInfo
                errorBanner
            }
            .padding(16)
        }
    }

    private func usageBar(_ label: String, _ utilization: Double, _ reset: Date) -> some View {
        let percent = Int(utilization * 100)
        let color = barColor(utilization)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(color)
                        .frame(width: 8, height: 8)
                    Text(label)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Text("\(percent)%")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color(white: 0.2))
                    RoundedRectangle(cornerRadius: 7)
                        .fill(color)
                        .frame(width: geo.size.width * min(utilization, 1.0))
                        .animation(.easeInOut(duration: 0.6), value: utilization)
                }
            }
            .frame(height: 14)

            Text("Resets \(Formatting.resetTime(reset))")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.5))
        }
        .padding(14)
        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(white: 0.2)))
        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
    }

    private var sessionInfo: some View {
        HStack(spacing: 12) {
            HStack(spacing: 4) {
                Circle().fill(.green).frame(width: 6, height: 6)
                Text("\(store.activeSessions.count) active")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }

            if let cache = store.statsCache {
                Text("·").foregroundStyle(.white.opacity(0.4))
                Text("\(Formatting.tokens(cache.totalMessages)) all-time msgs")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let error = store.errorMessage {
            HStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10))
                Text(error).font(.system(size: 10, weight: .medium)).lineLimit(2)
            }
            .foregroundStyle(.red)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func barColor(_ utilization: Double) -> Color {
        switch utilization {
        case 0..<0.4: return .green
        case 0.4..<0.7: return .blue
        case 0.7..<0.9: return .orange
        default: return .red
        }
    }
}
