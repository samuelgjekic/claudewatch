import Foundation

actor LocalDataService {
    private let claudeDir: URL
    private let decoder = JSONDecoder()

    init() {
        self.claudeDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
    }

    // MARK: - stats-cache.json

    func loadStatsCache() throws -> StatsCache {
        let url = claudeDir.appendingPathComponent("stats-cache.json")
        let data = try Data(contentsOf: url)
        return try decoder.decode(StatsCache.self, from: data)
    }

    // MARK: - sessions/*.json

    func loadActiveSessions() throws -> [ActiveSession] {
        let sessionsDir = claudeDir.appendingPathComponent("sessions")
        guard FileManager.default.fileExists(atPath: sessionsDir.path) else { return [] }

        let files = try FileManager.default.contentsOfDirectory(
            at: sessionsDir, includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }

        return files.compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let session = try? decoder.decode(ActiveSession.self, from: data)
            else { return nil }
            return session
        }.filter { isProcessRunning(pid: $0.pid) }
    }

    private func isProcessRunning(pid: Int) -> Bool {
        kill(Int32(pid), 0) == 0
    }

    // MARK: - history.jsonl

    func loadHistory(maxLines: Int = 5000) throws -> [HistoryEntry] {
        let url = claudeDir.appendingPathComponent("history.jsonl")
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        let content = try String(contentsOf: url, encoding: .utf8)
        let lines = content.components(separatedBy: "\n")

        return lines.suffix(maxLines).compactMap { line in
            guard !line.isEmpty, let data = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(HistoryEntry.self, from: data)
        }
    }

    // MARK: - Build conversation summaries

    func buildConversations(from entries: [HistoryEntry], totalMessages: Int) -> [ConversationSummary] {
        var grouped: [String: [HistoryEntry]] = [:]
        for entry in entries {
            grouped[entry.sessionId, default: []].append(entry)
        }

        return grouped.compactMap { sessionId, msgs in
            guard msgs.count >= 1 else { return nil }
            let sorted = msgs.sorted { $0.timestamp < $1.timestamp }
            let firstTs = Date(timeIntervalSince1970: Double(sorted.first!.timestamp) / 1000)
            let lastTs = Date(timeIntervalSince1970: Double(sorted.last!.timestamp) / 1000)
            let duration = lastTs.timeIntervalSince(firstTs)
            let project = sorted.first!.project
            let name = (project as NSString).lastPathComponent

            let sparkline = buildSparkline(timestamps: sorted.map(\.timestamp), buckets: 20)

            let pct = totalMessages > 0 ? Double(msgs.count) / Double(totalMessages) * 100 : 0

            return ConversationSummary(
                id: sessionId,
                sessionId: sessionId,
                projectPath: project,
                projectName: name.isEmpty ? "~" : name,
                messageCount: msgs.count,
                firstTimestamp: firstTs,
                lastTimestamp: lastTs,
                duration: duration,
                percentOfTotal: pct,
                sparklineData: sparkline
            )
        }
        .sorted { $0.lastTimestamp > $1.lastTimestamp }
    }

    private func buildSparkline(timestamps: [Int], buckets: Int) -> [Double] {
        guard timestamps.count >= 2,
              let first = timestamps.first, let last = timestamps.last
        else { return [Double(timestamps.count)] }

        let range = Double(last - first)
        guard range > 0 else { return [Double(timestamps.count)] }

        var result = Array(repeating: 0.0, count: buckets)
        for ts in timestamps {
            let norm = (Double(ts) - Double(first)) / range
            let idx = min(Int(norm * Double(buckets)), buckets - 1)
            result[idx] += 1
        }
        return result
    }
}
