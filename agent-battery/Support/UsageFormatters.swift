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
            return String(localized: "formatter.percentUnknown")
        }
        return "\(Int(UsageMath.clampPercent(value).rounded()))%"
    }

    static func resetText(_ date: Date?, now: Date = Date()) -> String {
        guard let date else {
            return String(localized: "formatter.resetUnavailable")
        }

        let seconds = date.timeIntervalSince(now)
        guard seconds > 0 else {
            return String(localized: "formatter.resetPassed")
        }

        if seconds < 24 * 60 * 60 {
            let hours = Int(seconds) / 3600
            let minutes = (Int(seconds) % 3600) / 60
            if hours > 0 {
                return String(format: NSLocalizedString("formatter.resetsInHM", comment: ""), hours, minutes)
            }
            return String(format: NSLocalizedString("formatter.resetsInM", comment: ""), max(minutes, 1))
        }

        return String(format: NSLocalizedString("formatter.resetsAt", comment: ""), absoluteResetFormatter.string(from: date))
    }

    static func updatedText(
        _ date: Date?,
        status: UsageStatus,
        now: Date = Date()
    ) -> String {
        guard let date else {
            return status == .available ? String(localized: "formatter.updatedUnavailable") : status.title
        }

        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 {
            return String(localized: "formatter.updatedJustNow")
        }

        if seconds < 60 * 60 {
            return String(format: NSLocalizedString("formatter.updatedMinutesAgo", comment: ""), Int(seconds / 60))
        }

        if seconds < 24 * 60 * 60 {
            return String(format: NSLocalizedString("formatter.updatedHoursAgo", comment: ""), Int(seconds / 3600))
        }

        return String(format: NSLocalizedString("formatter.updatedAt", comment: ""), clockFormatter.string(from: date))
    }
}
