import Foundation

enum UsageFormatters {
    private static let resetDetailFormatter: DateFormatter = {
        let formatter = DateFormatter()
        if Locale.current.identifier.hasPrefix("zh") {
            formatter.locale = Locale(identifier: "zh_Hans")
            formatter.dateFormat = "EEE HH:mm, M 月 d号"
        } else {
            formatter.dateFormat = "EEE HH:mm, MMM d"
        }
        return formatter
    }()

    static func percentText(_ value: Double?) -> String {
        guard let value else {
            return String(localized: "formatter.percentUnknown")
        }
        return "\(Int(UsageMath.clampPercent(value).rounded()))%"
    }

    static var resetRelativePrefixText: String {
        localizedSegment(
            "formatter.resetRelativePrefix",
            fallback: isChineseLocale ? "" : "Reset in "
        )
    }

    static var resetRelativeSuffixText: String {
        localizedSegment(
            "formatter.resetRelativeSuffix",
            fallback: isChineseLocale ? "后重置" : ""
        )
    }

    static func resetDetailText(_ date: Date) -> String {
        resetDetailFormatter.string(from: date)
    }

    private static var isChineseLocale: Bool {
        Locale.current.identifier.hasPrefix("zh")
    }

    private static func localizedSegment(_ key: String, fallback: String) -> String {
        let value = NSLocalizedString(key, comment: "")
        return value == key ? fallback : value
    }
}
