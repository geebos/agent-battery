import Combine
import Foundation
import ServiceManagement

final class AppSettings: ObservableObject {
    private enum Keys {
        static let claudeEnabled = "claudeEnabled"
        static let codexEnabled = "codexEnabled"
        static let primaryDisplayTool = "primaryDisplayTool"
        static let menuBarDisplayMode = "menuBarDisplayMode"
        static let refreshInterval = "refreshInterval"
        static let warningThreshold = "warningThreshold"
        static let criticalThreshold = "criticalThreshold"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let showWeeklyUsage = "showWeeklyUsage"
        static let codexSessionsPath = "codexSessionsPath"
    }

    private let defaults: UserDefaults
    private let claudeSetupService = ClaudeCodeSetupService()

    @Published var claudeEnabled: Bool {
        didSet { defaults.set(claudeEnabled, forKey: Keys.claudeEnabled) }
    }

    @Published var codexEnabled: Bool {
        didSet { defaults.set(codexEnabled, forKey: Keys.codexEnabled) }
    }

    @Published var primaryDisplayTool: PrimaryDisplayTool {
        didSet { defaults.set(primaryDisplayTool.rawValue, forKey: Keys.primaryDisplayTool) }
    }

    @Published var menuBarDisplayMode: MenuBarDisplayMode {
        didSet { defaults.set(menuBarDisplayMode.rawValue, forKey: Keys.menuBarDisplayMode) }
    }

    @Published var refreshInterval: RefreshInterval {
        didSet { defaults.set(refreshInterval.rawValue, forKey: Keys.refreshInterval) }
    }

    @Published var warningThreshold: Int {
        didSet { defaults.set(warningThreshold, forKey: Keys.warningThreshold) }
    }

    @Published var criticalThreshold: Int {
        didSet { defaults.set(criticalThreshold, forKey: Keys.criticalThreshold) }
    }

    @Published private(set) var launchAtLoginEnabled: Bool {
        didSet { defaults.set(launchAtLoginEnabled, forKey: Keys.launchAtLoginEnabled) }
    }

    @Published var launchAtLoginMessage: String?

    @Published var showWeeklyUsage: Bool {
        didSet { defaults.set(showWeeklyUsage, forKey: Keys.showWeeklyUsage) }
    }

    @Published var codexSessionsPath: String {
        didSet { defaults.set(codexSessionsPath, forKey: Keys.codexSessionsPath) }
    }

    @Published private(set) var claudeSetupStatus: ClaudeSetupStatus = .unknown
    @Published var claudeSetupMessage: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        claudeEnabled = Self.bool(defaults, Keys.claudeEnabled, defaultValue: true)
        codexEnabled = Self.bool(defaults, Keys.codexEnabled, defaultValue: true)
        primaryDisplayTool = PrimaryDisplayTool(
            rawValue: defaults.string(forKey: Keys.primaryDisplayTool) ?? ""
        ) ?? .automatic
        menuBarDisplayMode = MenuBarDisplayMode(
            rawValue: defaults.string(forKey: Keys.menuBarDisplayMode) ?? ""
        ) ?? .batteryAndPercent
        refreshInterval = RefreshInterval(
            rawValue: defaults.integer(forKey: Keys.refreshInterval)
        ) ?? .oneMinute
        warningThreshold = Self.int(defaults, Keys.warningThreshold, defaultValue: 40, range: 16...95)
        criticalThreshold = Self.int(defaults, Keys.criticalThreshold, defaultValue: 15, range: 1...39)
        launchAtLoginEnabled = Self.bool(
            defaults,
            Keys.launchAtLoginEnabled,
            defaultValue: SMAppService.mainApp.status == .enabled
        )
        launchAtLoginMessage = nil
        showWeeklyUsage = Self.bool(defaults, Keys.showWeeklyUsage, defaultValue: true)
        codexSessionsPath = defaults.string(forKey: Keys.codexSessionsPath) ?? UsageDefaults.codexSessionsPath
        refreshClaudeSetupStatus()
    }

    var dataConfiguration: UsageDataConfiguration {
        UsageDataConfiguration(
            claudeUsagePath: UsageDefaults.claudeUsagePath,
            codexSessionsPath: codexSessionsPath,
            staleInterval: 10 * 60
        )
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }

            launchAtLoginMessage = nil
            launchAtLoginEnabled = enabled
        } catch {
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            launchAtLoginMessage = error.localizedDescription
        }
    }

    func installClaudeCodeSetup() {
        do {
            let result = try claudeSetupService.install(configuration: claudeSetupConfiguration)
            claudeSetupStatus = result.status
            claudeSetupMessage = result.message
            claudeEnabled = true
        } catch {
            claudeSetupStatus = .failed
            claudeSetupMessage = error.localizedDescription
        }
    }

    func refreshClaudeSetupStatus() {
        claudeSetupStatus = claudeSetupService.status(configuration: claudeSetupConfiguration)
    }

    func isEnabled(_ tool: UsageTool) -> Bool {
        switch tool {
        case .claudeCode:
            claudeEnabled
        case .codex:
            codexEnabled
        }
    }

    private static func bool(
        _ defaults: UserDefaults,
        _ key: String,
        defaultValue: Bool
    ) -> Bool {
        defaults.object(forKey: key) as? Bool ?? defaultValue
    }

    private static func int(
        _ defaults: UserDefaults,
        _ key: String,
        defaultValue: Int,
        range: ClosedRange<Int>
    ) -> Int {
        guard defaults.object(forKey: key) != nil else {
            return defaultValue
        }

        return min(max(defaults.integer(forKey: key), range.lowerBound), range.upperBound)
    }

    private var claudeSetupConfiguration: ClaudeSetupConfiguration {
        .default()
    }
}
