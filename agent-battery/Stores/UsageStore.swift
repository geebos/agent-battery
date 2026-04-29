import Combine
import Foundation

final class UsageStore: ObservableObject {
    @Published private(set) var snapshots: [UsageTool: UsageSnapshot]
    @Published private(set) var lastRefreshAt: Date?

    private let settings: AppSettings
    private let claudeProvider = ClaudeCodeUsageProvider()
    private let codexProvider = CodexUsageProvider()
    private let snapshotCache: UsageSnapshotCache
    private let refreshQueue = DispatchQueue(label: "agent-battery.usage-store.refresh", qos: .userInitiated)
    private var refreshTimer: Timer?
    private var didPerformLaunchRefresh = false
    private var cancellables = Set<AnyCancellable>()

    init(
        settings: AppSettings,
        snapshotCache: UsageSnapshotCache = UsageSnapshotCache()
    ) {
        self.settings = settings
        self.snapshotCache = snapshotCache
        snapshots = Self.initialSnapshots(from: snapshotCache)

        settings.objectWillChange
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.scheduleRefreshTimer()
                self?.refresh()
            }
            .store(in: &cancellables)

        scheduleRefreshTimer()
        refreshOnLaunch()
    }

    deinit {
        refreshTimer?.invalidate()
    }

    var enabledTools: [UsageTool] {
        UsageTool.allCases.filter { settings.isEnabled($0) }
    }

    var primarySnapshot: UsageSnapshot {
        if let tool = settings.primaryDisplayTool.usageTool {
            return snapshot(for: tool)
        }

        let enabledSnapshots = enabledTools.map { snapshot(for: $0) }
        return enabledSnapshots
            .filter { $0.fiveHourRemainingPercent != nil }
            .min {
                ($0.fiveHourRemainingPercent ?? 100) < ($1.fiveHourRemainingPercent ?? 100)
            }
            ?? enabledSnapshots.first
            ?? UsageSnapshot.unavailable(tool: .claudeCode, message: "No enabled tools.")
    }

    func snapshot(for tool: UsageTool) -> UsageSnapshot {
        snapshots[tool] ?? UsageSnapshot.unavailable(tool: tool, message: "Waiting for first refresh.")
    }

    func level(for snapshot: UsageSnapshot) -> UsageLevel {
        UsageMath.level(
            for: snapshot.fiveHourRemainingPercent,
            warningThreshold: settings.warningThreshold,
            criticalThreshold: settings.criticalThreshold
        )
    }

    func refresh() {
        let configuration = settings.dataConfiguration
        let enabledTools = Dictionary(uniqueKeysWithValues: UsageTool.allCases.map { ($0, settings.isEnabled($0)) })

        refreshQueue.async { [weak self] in
            guard let self else { return }
            let now = Date()
            let claudeRaw = self.rawSnapshot(for: .claudeCode, isEnabled: enabledTools[.claudeCode] ?? false, configuration: configuration)
            let codexRaw = self.rawSnapshot(for: .codex, isEnabled: enabledTools[.codex] ?? false, configuration: configuration)

            DispatchQueue.main.async {
                var nextSnapshots = self.snapshots
                nextSnapshots[.claudeCode] = self.resolvedSnapshot(claudeRaw, now: now)
                nextSnapshots[.codex] = self.resolvedSnapshot(codexRaw, now: now)
                self.snapshots = nextSnapshots
                self.lastRefreshAt = now
            }
        }
    }

    func refreshOnLaunch() {
        guard !didPerformLaunchRefresh else {
            return
        }

        didPerformLaunchRefresh = true
        refresh()
        scheduleCodexLaunchRefresh()
    }

    private func scheduleRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(settings.refreshInterval.rawValue), repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    private func scheduleCodexLaunchRefresh() {
        DispatchQueue.main.async { [weak self] in
            self?.refreshCodex()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.refreshCodex()
        }
    }

    private func refreshCodex() {
        let configuration = settings.dataConfiguration
        let isEnabled = settings.isEnabled(.codex)

        refreshQueue.async { [weak self] in
            guard let self else { return }
            let now = Date()
            let codexRaw = self.rawSnapshot(for: .codex, isEnabled: isEnabled, configuration: configuration)

            DispatchQueue.main.async {
                var nextSnapshots = self.snapshots
                nextSnapshots[.codex] = self.resolvedSnapshot(codexRaw, now: now)
                self.snapshots = nextSnapshots
                self.lastRefreshAt = now
            }
        }
    }

    private func rawSnapshot(
        for tool: UsageTool,
        isEnabled: Bool,
        configuration: UsageDataConfiguration
    ) -> UsageSnapshot {
        guard isEnabled else {
            return .disabled(tool: tool)
        }

        switch tool {
        case .claudeCode:
            return claudeProvider.fetch(configuration: configuration)
        case .codex:
            return codexProvider.fetch(configuration: configuration)
        }
    }

    private func resolvedSnapshot(_ newSnapshot: UsageSnapshot, now: Date) -> UsageSnapshot {
        let projectedSnapshot = newSnapshot.projectingElapsedResets(now: now)
        if projectedSnapshot.hasUsageValues {
            snapshotCache.store(projectedSnapshot, now: now)
            return projectedSnapshot
        }

        if let cachedSnapshot = snapshotCache.snapshot(for: projectedSnapshot.tool, now: now) {
            snapshotCache.store(cachedSnapshot, now: now)
            return cachedSnapshot.replacingStatus(
                .stale,
                message: fallbackMessage(from: projectedSnapshot)
            )
        }

        return snapshotPreservingPreviousValues(projectedSnapshot, now: now)
    }

    private func snapshotPreservingPreviousValues(
        _ newSnapshot: UsageSnapshot,
        now: Date
    ) -> UsageSnapshot {
        guard
            let previous = snapshots[newSnapshot.tool],
            previous.hasUsageValues
        else {
            return newSnapshot
        }

        return previous
            .projectingElapsedResets(now: now)
            .replacingStatus(
                .stale,
                message: fallbackMessage(from: newSnapshot)
            )
    }

    private func fallbackMessage(from sourceSnapshot: UsageSnapshot) -> String {
        if let message = sourceSnapshot.message, !message.isEmpty {
            return "Using cached data; \(message)"
        }

        return "Using cached data."
    }

    private static func initialSnapshots(from snapshotCache: UsageSnapshotCache) -> [UsageTool: UsageSnapshot] {
        Dictionary(
            uniqueKeysWithValues: UsageTool.allCases.map { tool in
                let snapshot = snapshotCache.snapshot(for: tool)?
                    .replacingStatus(.stale, message: "Using cached data.")
                    ?? UsageSnapshot.unavailable(tool: tool, message: "Waiting for first refresh.")
                return (tool, snapshot)
            }
        )
    }
}
