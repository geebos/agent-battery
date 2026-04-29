import Foundation

struct ClaudeCodeUsageProvider {
    func fetch(configuration: UsageDataConfiguration) -> UsageSnapshot {
        let path = NSString(string: configuration.claudeUsagePath).expandingTildeInPath
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: url.path) else {
            return .unavailable(
                tool: .claudeCode,
                message: String(format: NSLocalizedString("provider.claudeWaiting", comment: ""), configuration.claudeUsagePath)
            )
        }

        do {
            let data = try Data(contentsOf: url)
            guard
                let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            else {
                return .error(tool: .claudeCode, message: String(localized: "provider.claudeNotJsonObject"))
            }

            return Self.snapshot(from: object, staleInterval: configuration.staleInterval)
        } catch {
            return .error(tool: .claudeCode, message: error.localizedDescription)
        }
    }

    private static func snapshot(
        from object: [String: Any],
        staleInterval: TimeInterval
    ) -> UsageSnapshot {
        let rateLimits = object["rate_limits"] as? [String: Any] ?? object
        let fiveHour = rateLimits["five_hour"] as? [String: Any]
        let sevenDay = rateLimits["seven_day"] as? [String: Any]

        let fiveRemaining = number(object["fiveHourRemainingPercent"])
            ?? remainingPercent(from: fiveHour)
        let weeklyRemaining = number(object["weeklyRemainingPercent"])
            ?? remainingPercent(from: sevenDay)
        let updatedAt = date(from: object["updated_at"])
            ?? date(from: object["updatedAt"])
        let fiveResetAt = date(from: object["fiveHourResetAt"])
            ?? date(from: fiveHour?["resets_at"])
        let weeklyResetAt = date(from: object["weeklyResetAt"])
            ?? date(from: sevenDay?["resets_at"])

        guard fiveRemaining != nil || weeklyRemaining != nil else {
            return .unavailable(
                tool: .claudeCode,
                message: String(localized: "provider.claudeMissingRateLimits"),
                updatedAt: updatedAt
            )
        }

        let status: UsageStatus = if let updatedAt, Date().timeIntervalSince(updatedAt) > staleInterval {
            .stale
        } else {
            .available
        }

        return UsageSnapshot(
            tool: .claudeCode,
            fiveHourRemainingPercent: fiveRemaining,
            weeklyRemainingPercent: weeklyRemaining,
            fiveHourResetAt: fiveResetAt,
            weeklyResetAt: weeklyResetAt,
            updatedAt: updatedAt,
            status: status,
            message: nil
        )
    }

    private static func remainingPercent(from slot: [String: Any]?) -> Double? {
        UsageMath.remainingPercent(fromUsedPercent: number(slot?["used_percentage"]))
    }

    private static func number(_ value: Any?) -> Double? {
        switch value {
        case let value as Double:
            value
        case let value as Float:
            Double(value)
        case let value as Int:
            Double(value)
        case let value as NSNumber:
            value.doubleValue
        case let value as String:
            Double(value)
        default:
            nil
        }
    }

    private static func date(from value: Any?) -> Date? {
        if let seconds = number(value) {
            let normalized = seconds > 10_000_000_000 ? seconds / 1000 : seconds
            return Date(timeIntervalSince1970: normalized)
        }

        if let string = value as? String {
            return ISO8601DateFormatter().date(from: string)
        }

        return nil
    }
}
