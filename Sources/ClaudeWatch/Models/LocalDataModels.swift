import Foundation
import SwiftUI

// MARK: - Real rate limit data from Anthropic API headers

struct RateLimitData {
    let sessionUtilization: Double
    let sessionReset: Date
    let weeklyUtilization: Double
    let weeklyReset: Date
    let overageUtilization: Double
    let overageReset: Date
    let fallbackAvailable: Bool
    let hasOverageTier: Bool

    var sessionPercent: Int { Int(sessionUtilization * 100) }
    var weeklyPercent: Int { Int(weeklyUtilization * 100) }
    var overagePercent: Int { Int(overageUtilization * 100) }

    var sessionRemaining: Int { max(0, 100 - sessionPercent) }
    var weeklyRemaining: Int { max(0, 100 - weeklyPercent) }

    static let empty = RateLimitData(
        sessionUtilization: 0, sessionReset: Date(),
        weeklyUtilization: 0, weeklyReset: Date(),
        overageUtilization: 0, overageReset: Date(),
        fallbackAvailable: false, hasOverageTier: false
    )
}

// MARK: - stats-cache.json

struct StatsCache: Codable {
    let version: Int
    let lastComputedDate: String
    let dailyActivity: [DailyActivity]
    let dailyModelTokens: [DailyModelTokens]
    let modelUsage: [String: ModelUsageEntry]
    let totalSessions: Int
    let totalMessages: Int
    let longestSession: LongestSession
    let firstSessionDate: String
    let hourCounts: [String: Int]
    let totalSpeculationTimeSavedMs: Int
}

struct DailyActivity: Codable, Identifiable {
    var id: String { date }
    let date: String
    let messageCount: Int
    let sessionCount: Int
    let toolCallCount: Int
}

struct DailyModelTokens: Codable {
    let date: String
    let tokensByModel: [String: Int]
}

struct ModelUsageEntry: Codable {
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadInputTokens: Int
    let cacheCreationInputTokens: Int
    let webSearchRequests: Int
    let costUSD: Int
    let contextWindow: Int
    let maxOutputTokens: Int

    var totalTokens: Int {
        inputTokens + outputTokens + cacheReadInputTokens + cacheCreationInputTokens
    }
}

struct LongestSession: Codable {
    let sessionId: String
    let duration: Int
    let messageCount: Int
    let timestamp: String
}

// MARK: - history.jsonl

struct HistoryEntry: Codable {
    let display: String
    let timestamp: Int
    let project: String
    let sessionId: String
}

// MARK: - sessions/*.json

struct ActiveSession: Codable, Identifiable {
    var id: Int { pid }
    let pid: Int
    let sessionId: String
    let cwd: String
    let startedAt: Int
    let version: String
    let peerProtocol: Int?
    let kind: String
    let entrypoint: String
    let name: String?
    let updatedAt: Int?
    let procStart: String?

    var startDate: Date { Date(timeIntervalSince1970: Double(startedAt) / 1000) }
    var projectName: String { (cwd as NSString).lastPathComponent }
    var duration: TimeInterval { Date().timeIntervalSince(startDate) }
}

// MARK: - Conversation summaries

struct ConversationSummary: Identifiable {
    let id: String
    let sessionId: String
    let projectPath: String
    let projectName: String
    let messageCount: Int
    let firstTimestamp: Date
    let lastTimestamp: Date
    let duration: TimeInterval
    let percentOfTotal: Double
    let sparklineData: [Double]
}

// MARK: - UI enums

enum MenuBarDisplay: String, CaseIterable {
    case session = "Session"
    case weekly = "Weekly"
    case both = "Both"
    case sonnet = "Sonnet"
}

enum PopoverTab: String, CaseIterable {
    case overview = "Overview"
    case sessions = "Sessions"
    case stats = "Stats"
}

// MARK: - Model helpers

enum ModelInfo {
    static func displayName(for model: String) -> String {
        if model.contains("opus-4-6") { return "Opus 4.6" }
        if model.contains("opus-4-7") { return "Opus 4.7" }
        if model.contains("sonnet-4-6") { return "Sonnet 4.6" }
        if model.contains("sonnet-4-5") { return "Sonnet 4.5" }
        if model.contains("opus-4-5") { return "Opus 4.5" }
        if model.contains("haiku-4-5") { return "Haiku 4.5" }
        return model
    }

    static func color(for model: String) -> Color {
        if model.contains("opus") { return .purple }
        if model.contains("sonnet") { return .blue }
        if model.contains("haiku") { return .teal }
        return .gray
    }

    static func icon(for model: String) -> String {
        if model.contains("opus") { return "brain.head.profile" }
        if model.contains("sonnet") { return "sparkles" }
        if model.contains("haiku") { return "hare" }
        return "cpu"
    }
}

// MARK: - Formatting

enum Formatting {
    static func tokens(_ count: Int) -> String {
        if count >= 1_000_000_000 { return String(format: "%.1fB", Double(count) / 1_000_000_000) }
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }

    static func duration(_ interval: TimeInterval) -> String {
        if interval < 60 { return "< 1m" }
        if interval < 3600 {
            return "\(Int(interval / 60))m"
        }
        let h = Int(interval / 3600)
        let m = Int(interval.truncatingRemainder(dividingBy: 3600) / 60)
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    static func resetTime(_ date: Date) -> String {
        let fmt = DateFormatter()
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            fmt.dateFormat = "h:mm a"
            return fmt.string(from: date)
        }
        fmt.dateFormat = "MMM d 'at' h:mm a"
        return fmt.string(from: date)
    }

    static func daysAgo(from dateString: String) -> Int? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateString) else { return nil }
        return Calendar.current.dateComponents([.day], from: date, to: Date()).day
    }
}
