import Foundation

struct UsageHistoryStore {
    private let defaults: UserDefaults
    private let maxEntriesPerTool: Int
    private let retention: TimeInterval
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        defaults: UserDefaults = .standard,
        maxEntriesPerTool: Int = 2_880,
        retention: TimeInterval = 7 * 24 * 60 * 60
    ) {
        self.defaults = defaults
        self.maxEntriesPerTool = max(1, maxEntriesPerTool)
        self.retention = retention
    }

    func history(for tool: UsageTool, now: Date = Date()) -> [UsageHistoryEntry] {
        guard let data = defaults.data(forKey: key(for: tool)),
              let decoded = try? decoder.decode([UsageHistoryEntry].self, from: data) else {
            return []
        }

        let entries = pruned(decoded, now: now)
        if entries != decoded {
            store(entries, for: tool)
        }
        return entries
    }

    @discardableResult
    func record(_ snapshot: UsageSnapshot, at date: Date = Date()) -> [UsageHistoryEntry] {
        let entry = UsageHistoryEntry(snapshot: snapshot, recordedAt: date)
        var entries = history(for: snapshot.tool, now: date)
        entries.append(entry)
        entries = pruned(entries, now: date)
        store(entries, for: snapshot.tool)
        return entries
    }

    private func pruned(_ entries: [UsageHistoryEntry], now: Date) -> [UsageHistoryEntry] {
        let cutoff = now.addingTimeInterval(-retention)
        let retained = entries
            .filter { $0.recordedAt >= cutoff }
            .sorted { $0.recordedAt < $1.recordedAt }

        guard retained.count > maxEntriesPerTool else {
            return retained
        }

        return Array(retained.suffix(maxEntriesPerTool))
    }

    private func store(_ entries: [UsageHistoryEntry], for tool: UsageTool) {
        guard let data = try? encoder.encode(entries) else {
            return
        }
        defaults.set(data, forKey: key(for: tool))
    }

    private func key(for tool: UsageTool) -> String {
        "usageHistory.\(tool.rawValue)"
    }
}
