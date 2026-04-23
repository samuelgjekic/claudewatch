import Foundation

actor RateLimitService {
    private static let debugLog = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude/claudewatch-debug.log")

    private func log(_ msg: String) {
        let line = "[\(Date())] [RateLimit] \(msg)\n"
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

    func fetchUsage(organizationId: String) async throws -> RateLimitData {
        let request = AuthService.makeRequest(path: "/api/organizations/\(organizationId)/usage")

        log("Fetching usage for org \(organizationId)...")
        let (data, response) = try await AuthService.apiSession.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            log("Invalid response (not HTTP)")
            throw UsageError.invalidResponse
        }

        let body = String(data: data, encoding: .utf8) ?? ""
        log("Response \(http.statusCode): \(String(body.prefix(1000)))")

        guard http.statusCode == 200 else {
            throw UsageError.apiError(http.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let str = try decoder.singleValueContainer().decode(String.self)
            if let date = iso.date(from: str) { return date }
            if let date = ISO8601DateFormatter().date(from: str) { return date }
            throw DecodingError.dataCorruptedError(in: try decoder.singleValueContainer(), debugDescription: "Bad date: \(str)")
        }

        let usage: UsageResponse
        do {
            usage = try decoder.decode(UsageResponse.self, from: data)
        } catch {
            log("Decode error: \(error)")
            throw UsageError.invalidResponse
        }

        log("Parsed: session=\(usage.fiveHour?.utilization ?? -1), weekly=\(usage.sevenDay?.utilization ?? -1), sonnet=\(usage.sevenDaySonnet?.utilization ?? -1)")

        return RateLimitData(
            sessionUtilization: (usage.fiveHour?.utilization ?? 0) / 100.0,
            sessionReset: usage.fiveHour?.resetsAt ?? Date(),
            weeklyUtilization: (usage.sevenDay?.utilization ?? 0) / 100.0,
            weeklyReset: usage.sevenDay?.resetsAt ?? Date(),
            overageUtilization: (usage.sevenDaySonnet?.utilization ?? 0) / 100.0,
            overageReset: usage.sevenDaySonnet?.resetsAt ?? Date(),
            fallbackAvailable: false,
            hasOverageTier: usage.sevenDaySonnet != nil
        )
    }

    enum UsageError: LocalizedError {
        case invalidResponse
        case apiError(Int)

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Invalid usage response"
            case .apiError(let code): return "Usage API error (\(code))"
            }
        }
    }
}

private struct UsageResponse: Codable {
    let fiveHour: UsageTier?
    let sevenDay: UsageTier?
    let sevenDayOpus: UsageTier?
    let sevenDaySonnet: UsageTier?
    let extraUsage: ExtraUsageTier?
}

private struct UsageTier: Codable {
    let utilization: Double?
    let resetsAt: Date?
}

private struct ExtraUsageTier: Codable {
    let isEnabled: Bool?
    let monthlyLimit: Double?
    let usedCredits: Double?
    let utilization: Double?

    enum CodingKeys: String, CodingKey {
        case isEnabled, monthlyLimit, usedCredits, utilization
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try? container.decode(Bool.self, forKey: .isEnabled)
        monthlyLimit = try? container.decode(Double.self, forKey: .monthlyLimit)
        usedCredits = try? container.decode(Double.self, forKey: .usedCredits)
        utilization = try? container.decode(Double.self, forKey: .utilization)
    }
}
