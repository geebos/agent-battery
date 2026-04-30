import Foundation

enum UsageMath {
    static func clampPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }

    static func remainingPercent(fromUsedPercent usedPercent: Double?) -> Double? {
        guard let usedPercent else {
            return nil
        }
        return clampPercent(100 - usedPercent)
    }

    static func level(
        for remainingPercent: Double?,
        warningThreshold: Int,
        criticalThreshold: Int
    ) -> UsageLevel {
        guard let remainingPercent else {
            return .unavailable
        }

        if remainingPercent <= Double(criticalThreshold) {
            return .critical
        }

        if remainingPercent <= Double(warningThreshold) {
            return .warning
        }

        return .normal
    }
}
