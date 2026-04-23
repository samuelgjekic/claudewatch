import SwiftUI

struct StatsTab: View {
    @ObservedObject var store: UsageStore

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                lifetimeCard
                modelBreakdown
                dailyActivityChart
                hourlyHeatmap
            }
            .padding(16)
        }
    }

    private var lifetimeCard: some View {
        HStack(spacing: 0) {
            statBlock(Formatting.tokens(store.statsCache?.totalSessions ?? 0), "Sessions")
            Divider().frame(height: 30)
            statBlock(Formatting.tokens(store.statsCache?.totalMessages ?? 0), "Messages")
            Divider().frame(height: 30)
            statBlock("\(store.daysUsingClaude)d", "Using Claude")
        }
        .padding(.vertical, 10)
        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color(white: 0.2)))
    }

    private func statBlock(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
    }

    private var modelBreakdown: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Models")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            if let usage = store.statsCache?.modelUsage {
                let sorted = usage.sorted { $0.value.totalTokens > $1.value.totalTokens }
                let totalTokens = sorted.map(\.value.totalTokens).reduce(0, +)

                ForEach(sorted, id: \.key) { model, entry in
                    modelRow(model: model, entry: entry, totalTokens: totalTokens)
                }
            }
        }
    }

    private func modelRow(model: String, entry: ModelUsageEntry, totalTokens: Int) -> some View {
        let fraction = totalTokens > 0 ? Double(entry.totalTokens) / Double(totalTokens) : 0

        return HStack(spacing: 8) {
            Image(systemName: ModelInfo.icon(for: model))
                .font(.system(size: 10))
                .foregroundStyle(ModelInfo.color(for: model))
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(ModelInfo.displayName(for: model))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(Formatting.tokens(entry.totalTokens) + " tokens")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.5))
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color(white: 0.15))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(ModelInfo.color(for: model).opacity(0.6))
                            .frame(width: geo.size.width * fraction)
                    }
                }
                .frame(height: 4)

                HStack(spacing: 8) {
                    Text("In: \(Formatting.tokens(entry.inputTokens))")
                    Text("Out: \(Formatting.tokens(entry.outputTokens))")
                    Text("Cache: \(Formatting.tokens(entry.cacheReadInputTokens))")
                }
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(8)
        .background(Color(white: 0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private var dailyActivityChart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Daily Activity (last 30 days)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            if let days = store.statsCache?.dailyActivity.suffix(30), !days.isEmpty {
                let data = days.map { Double($0.messageCount) }
                SparklineView(
                    data: Array(data),
                    color: .blue,
                    width: 330,
                    height: 40,
                    filled: true
                )
                HStack {
                    Text(days.first?.date.suffix(5) ?? "")
                    Spacer()
                    Text(days.last?.date.suffix(5) ?? "")
                }
                .font(.system(size: 8))
                .foregroundStyle(.white.opacity(0.35))
            }
        }
    }

    private var hourlyHeatmap: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hourly Distribution")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.6))

            if let counts = store.statsCache?.hourCounts {
                let maxCount = Double(counts.values.max() ?? 1)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 12), spacing: 2) {
                    ForEach(0..<24, id: \.self) { hour in
                        let count = Double(counts[String(hour)] ?? 0)
                        let intensity = maxCount > 0 ? count / maxCount : 0

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue.opacity(0.1 + intensity * 0.8))
                            .frame(height: 18)
                            .overlay(
                                Text("\(hour)")
                                    .font(.system(size: 7))
                                    .foregroundStyle(intensity > 0.5 ? .white : .white.opacity(0.5))
                            )
                    }
                }
            }
        }
    }
}
