import Foundation

enum UsageFormatters {
    private static let absoluteResetFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE HH:mm"
        return formatter
    }()

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    static func percentText(_ value: Double?) -> String {
        guard let value else {
            return "--%"
        }
        return "\(Int(UsageMath.clampPercent(value).rounded()))%"
    }

    static func resetText(_ date: Date?, now: Date = Date()) -> String {
        guard let date else {
            return "Reset time unavailable"
        }

        let seconds = date.timeIntervalSince(now)
        guard seconds > 0 else {
            return "Reset time passed"
        }

        if seconds < 24 * 60 * 60 {
            let hours = Int(seconds) / 3600
            let minutes = (Int(seconds) % 3600) / 60
            if hours > 0 {
                return "Resets in \(hours)h \(minutes)m"
            }
            return "Resets in \(max(minutes, 1))m"
        }

        return "Resets \(absoluteResetFormatter.string(from: date))"
    }

    static func updatedText(
        _ date: Date?,
        status: UsageStatus,
        now: Date = Date()
    ) -> String {
        guard let date else {
            return status == .available ? "Updated time unavailable" : status.title
        }

        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 {
            return "Updated just now"
        }

        if seconds < 60 * 60 {
            return "Updated \(Int(seconds / 60))m ago"
        }

        if seconds < 24 * 60 * 60 {
            return "Updated \(Int(seconds / 3600))h ago"
        }

        return "Updated \(clockFormatter.string(from: date))"
    }
}
