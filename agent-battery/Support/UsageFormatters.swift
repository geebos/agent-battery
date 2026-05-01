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

    static func resetCountdownText(
        until date: Date,
        now: Date = Date(),
        locale: Locale = .current
    ) -> String {
        let remainingSeconds = max(60, Int64(date.timeIntervalSince(now)))
        let days = remainingSeconds / (24 * 60 * 60)
        let hours = (remainingSeconds % (24 * 60 * 60)) / (60 * 60)
        let minutes = (remainingSeconds % (60 * 60)) / 60
        let units = [
            durationUnit(value: days, english: "d", chinese: "天", locale: locale),
            durationUnit(value: hours, english: "h", chinese: "小时", locale: locale),
            durationUnit(value: minutes, english: "m", chinese: "分钟", locale: locale),
        ]
            .compactMap { $0 }
            .prefix(2)

        return units.joined(separator: " ")
    }

    private static var isChineseLocale: Bool {
        Locale.current.identifier.hasPrefix("zh")
    }

    private static func durationUnit(
        value: Int64,
        english: String,
        chinese: String,
        locale: Locale
    ) -> String? {
        guard value > 0 else {
            return nil
        }

        if locale.identifier.hasPrefix("zh") {
            return "\(value) \(chinese)"
        }

        return "\(value)\(english)"
    }

    private static func localizedSegment(_ key: String, fallback: String) -> String {
        let value = NSLocalizedString(key, comment: "")
        return value == key ? fallback : value
    }
}
