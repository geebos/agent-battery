import Foundation

struct UsageSnapshotCache {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func snapshot(for tool: UsageTool, now: Date = Date()) -> UsageSnapshot? {
        guard let data = defaults.data(forKey: key(for: tool)),
              let snapshot = try? decoder.decode(UsageSnapshot.self, from: data) else {
            return nil
        }

        return snapshot.projectingElapsedResets(now: now)
    }

    func store(_ snapshot: UsageSnapshot, now: Date = Date()) {
        let projected = snapshot.projectingElapsedResets(now: now)
        guard projected.hasUsageValues,
              let data = try? encoder.encode(projected) else {
            return
        }

        defaults.set(data, forKey: key(for: projected.tool))
    }

    private func key(for tool: UsageTool) -> String {
        "usageSnapshotCache.\(tool.rawValue)"
    }
}

extension UsageSnapshot {
    var hasUsageValues: Bool {
        fiveHourRemainingPercent != nil || weeklyRemainingPercent != nil
    }

    func projectingElapsedResets(now: Date = Date()) -> UsageSnapshot {
        let fiveHourExpired = fiveHourResetAt.map { $0 <= now } ?? false
        let weeklyExpired = weeklyResetAt.map { $0 <= now } ?? false

        guard fiveHourExpired || weeklyExpired else {
            return self
        }

        return UsageSnapshot(
            tool: tool,
            fiveHourRemainingPercent: fiveHourExpired ? 100 : fiveHourRemainingPercent,
            weeklyRemainingPercent: weeklyExpired ? 100 : weeklyRemainingPercent,
            fiveHourResetAt: fiveHourExpired ? nil : fiveHourResetAt,
            weeklyResetAt: weeklyExpired ? nil : weeklyResetAt,
            updatedAt: updatedAt,
            status: status,
            message: message
        )
    }

    func replacingStatus(_ status: UsageStatus, message: String?) -> UsageSnapshot {
        UsageSnapshot(
            tool: tool,
            fiveHourRemainingPercent: fiveHourRemainingPercent,
            weeklyRemainingPercent: weeklyRemainingPercent,
            fiveHourResetAt: fiveHourResetAt,
            weeklyResetAt: weeklyResetAt,
            updatedAt: updatedAt,
            status: status,
            message: message
        )
    }
}
