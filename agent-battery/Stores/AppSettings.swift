import AppKit
import Combine
import Foundation
import ServiceManagement
import SwiftUI

final class AppSettings: ObservableObject {
    private enum Keys {
        static let claudeEnabled = "claudeEnabled"
        static let codexEnabled = "codexEnabled"
        static let primaryDisplayTool = "primaryDisplayTool"
        static let menuBarDisplayMode = "menuBarDisplayMode"
        static let showMenuBarPercent = "showMenuBarPercent"
        static let colorByUsage = "colorByUsage"
        static let refreshInterval = "refreshInterval"
        static let warningThreshold = "warningThreshold"
        static let criticalThreshold = "criticalThreshold"
        static let launchAtLoginEnabled = "launchAtLoginEnabled"
        static let showWeeklyUsage = "showWeeklyUsage"
        static let codexSessionsPath = "codexSessionsPath"
        static let usageColorLow = "usageColorLow"
        static let usageColorMid = "usageColorMid"
        static let usageColorHigh = "usageColorHigh"
    }

    enum UsageLevelColor: CaseIterable {
        case low, mid, high

        var defaultHex: String {
            switch self {
            case .low: "FF3B30"
            case .mid: "FF9500"
            case .high: "FFFFFF"
            }
        }
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

    @Published var showMenuBarPercent: Bool {
        didSet { defaults.set(showMenuBarPercent, forKey: Keys.showMenuBarPercent) }
    }

    @Published var colorByUsage: Bool {
        didSet { defaults.set(colorByUsage, forKey: Keys.colorByUsage) }
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

    @Published var usageColorLowHex: String {
        didSet { defaults.set(usageColorLowHex, forKey: Keys.usageColorLow) }
    }

    @Published var usageColorMidHex: String {
        didSet { defaults.set(usageColorMidHex, forKey: Keys.usageColorMid) }
    }

    @Published var usageColorHighHex: String {
        didSet { defaults.set(usageColorHighHex, forKey: Keys.usageColorHigh) }
    }

    var usageColorLow: Color { Color(hex: usageColorLowHex) ?? .red }
    var usageColorMid: Color { Color(hex: usageColorMidHex) ?? .orange }
    var usageColorHigh: Color { Color(hex: usageColorHighHex) ?? .white }

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
        ) ?? .battery
        showMenuBarPercent = Self.bool(defaults, Keys.showMenuBarPercent, defaultValue: true)
        colorByUsage = Self.bool(defaults, Keys.colorByUsage, defaultValue: true)
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
        usageColorLowHex = defaults.string(forKey: Keys.usageColorLow) ?? UsageLevelColor.low.defaultHex
        usageColorMidHex = defaults.string(forKey: Keys.usageColorMid) ?? UsageLevelColor.mid.defaultHex
        usageColorHighHex = defaults.string(forKey: Keys.usageColorHigh) ?? UsageLevelColor.high.defaultHex
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

extension Color {
    init?(hex: String) {
        var trimmed = hex
        if trimmed.hasPrefix("#") { trimmed.removeFirst() }
        guard trimmed.count == 6, let value = UInt32(trimmed, radix: 16) else { return nil }
        self = Color(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hexString: String {
        let nsColor = NSColor(self).usingColorSpace(.sRGB) ?? .white
        let r = Int((nsColor.redComponent * 255).rounded())
        let g = Int((nsColor.greenComponent * 255).rounded())
        let b = Int((nsColor.blueComponent * 255).rounded())
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
