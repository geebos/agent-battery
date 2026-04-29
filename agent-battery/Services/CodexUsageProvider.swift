import Foundation

struct CodexUsageProvider {
    private let maxTailBytes = 1_048_576
    private let maxRolloutFilesToScan = 80

    func fetch(configuration: UsageDataConfiguration) -> UsageSnapshot {
        let path = NSString(string: configuration.codexSessionsPath).expandingTildeInPath
        let rootURL = URL(fileURLWithPath: path)

        do {
            let rolloutURLs = try rolloutFiles(from: rootURL)
            guard !rolloutURLs.isEmpty else {
                return .unavailable(
                    tool: .codex,
                    message: String(format: NSLocalizedString("provider.codexNoRollouts", comment: ""), configuration.codexSessionsPath)
                )
            }

            var latestEvent: ParsedRateLimitEvent?
            for rolloutURL in rolloutURLs.prefix(maxRolloutFilesToScan) {
                let data = try tailData(from: rolloutURL)
                guard let text = String(data: data, encoding: .utf8) else {
                    continue
                }

                guard let event = parseLatestRateLimitEvent(from: text, fileURL: rolloutURL) else {
                    continue
                }

                if latestEvent == nil || event.updatedAt > latestEvent!.updatedAt {
                    latestEvent = event
                }
            }

            guard let latestEvent else {
                return .unavailable(
                    tool: .codex,
                    message: String(localized: "provider.codexNoEvent")
                )
            }

            return snapshot(from: latestEvent, staleInterval: configuration.staleInterval)
        } catch {
            return .error(tool: .codex, message: error.localizedDescription)
        }
    }

    private func rolloutFiles(from rootURL: URL) throws -> [URL] {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory) else {
            return []
        }

        if !isDirectory.boolValue {
            return rootURL.pathExtension == "jsonl" ? [rootURL] : []
        }

        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        var files: [(url: URL, modifiedAt: Date)] = []
        for case let fileURL as URL in enumerator {
            guard fileURL.pathExtension == "jsonl", fileURL.lastPathComponent.hasPrefix("rollout-") else {
                continue
            }

            let values = try fileURL.resourceValues(forKeys: Set(keys))
            guard values.isRegularFile == true else {
                continue
            }

            let modifiedAt = values.contentModificationDate ?? .distantPast
            files.append((fileURL, modifiedAt))
        }

        return files
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .map(\.url)
    }

    private func tailData(from url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        let size = try handle.seekToEnd()
        let offset = size > UInt64(maxTailBytes) ? size - UInt64(maxTailBytes) : 0
        try handle.seek(toOffset: offset)
        return try handle.readToEnd() ?? Data()
    }

    private func parseLatestRateLimitEvent(
        from text: String,
        fileURL: URL
    ) -> ParsedRateLimitEvent? {
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true).reversed() {
            guard
                let data = String(rawLine).data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                object["type"] as? String == "event_msg",
                let payload = object["payload"] as? [String: Any],
                payload["type"] as? String == "token_count",
                let rateLimits = payload["rate_limits"] as? [String: Any]
            else {
                continue
            }

            let parsed = parseSlots(rateLimits)
            guard parsed.fiveHourRemaining != nil || parsed.weeklyRemaining != nil else {
                continue
            }

            let updatedAt = date(from: object["timestamp"]) ?? modificationDate(for: fileURL)
            return ParsedRateLimitEvent(
                fiveHourRemainingPercent: parsed.fiveHourRemaining,
                weeklyRemainingPercent: parsed.weeklyRemaining,
                fiveHourResetAt: parsed.fiveHourResetAt,
                weeklyResetAt: parsed.weeklyResetAt,
                updatedAt: updatedAt ?? .distantPast
            )
        }

        return nil
    }

    private func snapshot(
        from event: ParsedRateLimitEvent,
        staleInterval: TimeInterval
    ) -> UsageSnapshot {
        let status: UsageStatus = Date().timeIntervalSince(event.updatedAt) > staleInterval
            ? .stale
            : .available

        return UsageSnapshot(
            tool: .codex,
            fiveHourRemainingPercent: event.fiveHourRemainingPercent,
            weeklyRemainingPercent: event.weeklyRemainingPercent,
            fiveHourResetAt: event.fiveHourResetAt,
            weeklyResetAt: event.weeklyResetAt,
            updatedAt: event.updatedAt == .distantPast ? nil : event.updatedAt,
            status: status,
            message: nil
        )
    }

    private func parseSlots(_ rateLimits: [String: Any]) -> (
        fiveHourRemaining: Double?,
        weeklyRemaining: Double?,
        fiveHourResetAt: Date?,
        weeklyResetAt: Date?
    ) {
        var fiveHourRemaining: Double?
        var weeklyRemaining: Double?
        var fiveHourResetAt: Date?
        var weeklyResetAt: Date?

        for key in ["primary", "secondary"] {
            guard let slot = rateLimits[key] as? [String: Any] else {
                continue
            }

            let usedPercent = number(slot["used_percent"]) ?? number(slot["used_percentage"])
            let remaining = UsageMath.remainingPercent(fromUsedPercent: usedPercent)
            let resetAt = date(from: slot["resets_at"])
            let windowMinutes = number(slot["window_minutes"])

            if let windowMinutes, windowMinutes <= 300 {
                fiveHourRemaining = remaining
                fiveHourResetAt = resetAt
            } else {
                weeklyRemaining = remaining
                weeklyResetAt = resetAt
            }
        }

        return (fiveHourRemaining, weeklyRemaining, fiveHourResetAt, weeklyResetAt)
    }

    private func modificationDate(for url: URL) -> Date? {
        try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
    }

    private func number(_ value: Any?) -> Double? {
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

    private func date(from value: Any?) -> Date? {
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

private struct ParsedRateLimitEvent {
    let fiveHourRemainingPercent: Double?
    let weeklyRemainingPercent: Double?
    let fiveHourResetAt: Date?
    let weeklyResetAt: Date?
    let updatedAt: Date
}
