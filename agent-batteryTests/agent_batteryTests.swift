import Foundation
import Testing
@testable import agent_battery

struct AgentBatteryTests {
    @Test func remainingPercentConvertsUsedPercent() {
        #expect(UsageMath.remainingPercent(fromUsedPercent: 0) == 100)
        #expect(UsageMath.remainingPercent(fromUsedPercent: 38.4) == 61.6)
        #expect(UsageMath.remainingPercent(fromUsedPercent: 120) == 0)
        #expect(UsageMath.remainingPercent(fromUsedPercent: -12) == 100)
    }

    @Test func percentTextRoundsAndHandlesMissingValues() {
        #expect(UsageFormatters.percentText(61.6) == "62%")
        #expect(UsageFormatters.percentText(nil) == "--%")
        #expect(UsageFormatters.percentText(140) == "100%")
        #expect(UsageFormatters.percentText(-10) == "0%")
    }

    @Test func warningLevelsFollowConfiguredThresholds() {
        #expect(UsageMath.level(for: 62, warningThreshold: 40, criticalThreshold: 15) == .normal)
        #expect(UsageMath.level(for: 18, warningThreshold: 40, criticalThreshold: 15) == .warning)
        #expect(UsageMath.level(for: 12, warningThreshold: 40, criticalThreshold: 15) == .critical)
        #expect(UsageMath.level(for: nil, warningThreshold: 40, criticalThreshold: 15) == .unavailable)
    }

    @Test func appSettingsUsesClaudeUsageFileUnderDotClaude() throws {
        let suiteName = "agent-battery-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(defaults: defaults)

        #expect(settings.dataConfiguration.claudeUsagePath == UsageDefaults.claudeUsagePath)
    }

    @Test func cachedSnapshotsProjectElapsedResetWindows() throws {
        let suiteName = "agent-battery-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let cache = UsageSnapshotCache(defaults: defaults)
        let now = Date(timeIntervalSince1970: 1_000)
        let snapshot = UsageSnapshot(
            tool: .claudeCode,
            fiveHourRemainingPercent: 45,
            weeklyRemainingPercent: 60,
            fiveHourResetAt: now.addingTimeInterval(60 * 60),
            weeklyResetAt: now.addingTimeInterval(24 * 60 * 60),
            updatedAt: now,
            status: .available,
            message: nil
        )

        cache.store(snapshot, now: now)

        let beforeReset = try #require(cache.snapshot(for: .claudeCode, now: now.addingTimeInterval(30 * 60)))
        let afterFiveHourReset = try #require(cache.snapshot(for: .claudeCode, now: now.addingTimeInterval(2 * 60 * 60)))

        #expect(beforeReset.fiveHourRemainingPercent == 45)
        #expect(beforeReset.weeklyRemainingPercent == 60)
        #expect(afterFiveHourReset.fiveHourRemainingPercent == 100)
        #expect(afterFiveHourReset.fiveHourResetAt == nil)
        #expect(afterFiveHourReset.weeklyRemainingPercent == 60)
        #expect(afterFiveHourReset.weeklyResetAt == snapshot.weeklyResetAt)
    }

    @Test func codexProviderUsesLatestRateLimitEventAcrossRollouts() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-battery-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let olderEventInNewerFile = directory.appendingPathComponent("rollout-newer-file.jsonl")
        let newerEventInOlderFile = directory.appendingPathComponent("rollout-older-file.jsonl")

        try codexLine(
            timestamp: "2026-04-29T10:00:00Z",
            fiveHourUsed: 80,
            weeklyUsed: 30
        ).write(to: olderEventInNewerFile, atomically: true, encoding: .utf8)
        try codexLine(
            timestamp: "2026-04-29T12:00:00Z",
            fiveHourUsed: 25,
            weeklyUsed: 10
        ).write(to: newerEventInOlderFile, atomically: true, encoding: .utf8)

        try FileManager.default.setAttributes(
            [.modificationDate: Date()],
            ofItemAtPath: olderEventInNewerFile.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSinceNow: -60)],
            ofItemAtPath: newerEventInOlderFile.path
        )

        let snapshot = CodexUsageProvider().fetch(
            configuration: UsageDataConfiguration(
                claudeUsagePath: "",
                codexSessionsPath: directory.path,
                staleInterval: .greatestFiniteMagnitude
            )
        )

        #expect(snapshot.status == .available)
        #expect(snapshot.fiveHourRemainingPercent == 75)
        #expect(snapshot.weeklyRemainingPercent == 90)
    }

    @Test func usageStoreFetchesLatestCodexUsageOnStartup() throws {
        let suiteName = "agent-battery-tests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-battery-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: directory)
        }

        let now = Date()
        let rolloutURL = directory.appendingPathComponent("rollout-startup.jsonl")
        try codexLine(
            timestamp: ISO8601DateFormatter().string(from: now),
            fiveHourUsed: 21,
            weeklyUsed: 34,
            fiveHourResetsAt: now.addingTimeInterval(60 * 60),
            weeklyResetsAt: now.addingTimeInterval(24 * 60 * 60)
        ).write(to: rolloutURL, atomically: true, encoding: .utf8)

        let settings = AppSettings(defaults: defaults)
        settings.claudeEnabled = false
        settings.codexEnabled = true
        settings.codexSessionsPath = directory.path
        let store = UsageStore(settings: settings, snapshotCache: UsageSnapshotCache(defaults: defaults))
        let snapshot = store.snapshot(for: .codex)

        #expect(snapshot.status == .available)
        #expect(snapshot.fiveHourRemainingPercent == 79)
        #expect(snapshot.weeklyRemainingPercent == 66)
    }

    @Test func claudeSetupInstallsWrapperAndPreservesExistingStatusLine() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-battery-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let settingsURL = directory.appendingPathComponent(".claude/settings.json")
        let supportURL = directory.appendingPathComponent(".agent-battery")
        let usageURL = directory.appendingPathComponent("cc-rate-limit.json")
        try FileManager.default.createDirectory(
            at: settingsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        try """
        {"statusLine":{"type":"command","command":"printf existing-status"}}
        """.write(to: settingsURL, atomically: true, encoding: .utf8)

        let configuration = ClaudeSetupConfiguration(
            claudeSettingsPath: settingsURL.path,
            supportDirectoryPath: supportURL.path,
            usageOutputPath: usageURL.path
        )
        let service = ClaudeCodeSetupService()

        let firstResult = try service.install(configuration: configuration)
        let secondResult = try service.install(configuration: configuration)

        let settings = try jsonObject(from: settingsURL)
        let statusLine = try #require(settings["statusLine"] as? [String: Any])
        let command = try #require(statusLine["command"] as? String)
        let wrapperURL = supportURL.appendingPathComponent("claude-status-line-wrapper.sh")
        let preservedURL = supportURL.appendingPathComponent("claude-status-line-preserved-command.txt")
        let wrapper = try String(contentsOf: wrapperURL, encoding: .utf8)
        let preservedCommand = try String(contentsOf: preservedURL, encoding: .utf8)

        #expect(firstResult.status == .installed)
        #expect(secondResult.status == .installed)
        #expect(service.status(configuration: configuration) == .installed)
        #expect(command == wrapperURL.path)
        #expect(statusLine["type"] as? String == "command")
        #expect(wrapper.contains("PRESERVED_COMMAND='printf existing-status'"))
        #expect(preservedCommand == "printf existing-status")
    }

    @Test func claudeSetupRepairsCollectorWhenUsageOutputPathChanges() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-battery-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let settingsURL = directory.appendingPathComponent(".claude/settings.json")
        let supportURL = directory.appendingPathComponent(".agent-battery")
        let oldUsageURL = directory.appendingPathComponent("cc-rate-limit.json")
        let newUsageURL = directory.appendingPathComponent(".claude/cc-rate-limit.json")
        let service = ClaudeCodeSetupService()

        let oldConfiguration = ClaudeSetupConfiguration(
            claudeSettingsPath: settingsURL.path,
            supportDirectoryPath: supportURL.path,
            usageOutputPath: oldUsageURL.path
        )
        let newConfiguration = ClaudeSetupConfiguration(
            claudeSettingsPath: settingsURL.path,
            supportDirectoryPath: supportURL.path,
            usageOutputPath: newUsageURL.path
        )

        _ = try service.install(configuration: oldConfiguration)

        #expect(service.status(configuration: newConfiguration) == .needsRepair)

        _ = try service.install(configuration: newConfiguration)
        let collectorURL = supportURL.appendingPathComponent("claude-rate-limit-writer.sh")
        let collector = try String(contentsOf: collectorURL, encoding: .utf8)

        #expect(service.status(configuration: newConfiguration) == .installed)
        #expect(collector.contains("OUTPUT_PATH='\(newUsageURL.path)'"))
    }

    private func codexLine(
        timestamp: String,
        fiveHourUsed: Double,
        weeklyUsed: Double
    ) -> String {
        codexLine(
            timestamp: timestamp,
            fiveHourUsed: fiveHourUsed,
            weeklyUsed: weeklyUsed,
            fiveHourResetsAt: Date(timeIntervalSince1970: 1_777_479_241),
            weeklyResetsAt: Date(timeIntervalSince1970: 1_777_996_864)
        )
    }

    private func codexLine(
        timestamp: String,
        fiveHourUsed: Double,
        weeklyUsed: Double,
        fiveHourResetsAt: Date,
        weeklyResetsAt: Date
    ) -> String {
        """
        {"timestamp":"\(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{},"rate_limits":{"limit_id":"codex","primary":{"used_percent":\(fiveHourUsed),"window_minutes":300,"resets_at":\(Int(fiveHourResetsAt.timeIntervalSince1970))},"secondary":{"used_percent":\(weeklyUsed),"window_minutes":10080,"resets_at":\(Int(weeklyResetsAt.timeIntervalSince1970))},"plan_type":"plus"}}}

        """
    }

    private func jsonObject(from url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
