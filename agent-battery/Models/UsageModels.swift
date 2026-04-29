import Foundation

enum UsageDefaults {
    static let claudeUsagePath = "~/.claude/cc-rate-limit.json"
    static let codexSessionsPath = "~/.codex/sessions"
}

enum UsageTool: String, CaseIterable, Codable, Hashable, Identifiable {
    case claudeCode = "claude_code"
    case codex

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claudeCode:
            String(localized: "tool.claudeCodeName")
        case .codex:
            String(localized: "tool.codexName")
        }
    }

    var shortName: String {
        switch self {
        case .claudeCode:
            String(localized: "tool.claudeShortName")
        case .codex:
            String(localized: "tool.codexShortName")
        }
    }

    var systemImage: String {
        switch self {
        case .claudeCode:
            "sparkles"
        case .codex:
            "terminal"
        }
    }
}

enum UsageStatus: String, Codable, Hashable {
    case available
    case unavailable
    case stale
    case error

    var title: String {
        switch self {
        case .available:
            String(localized: "status.available")
        case .unavailable:
            String(localized: "status.unavailable")
        case .stale:
            String(localized: "status.stale")
        case .error:
            String(localized: "status.error")
        }
    }
}

enum UsageLevel {
    case normal
    case warning
    case critical
    case unavailable
}

struct UsageSnapshot: Codable, Identifiable, Equatable {
    var id: UsageTool { tool }

    let tool: UsageTool
    let fiveHourRemainingPercent: Double?
    let weeklyRemainingPercent: Double?
    let fiveHourResetAt: Date?
    let weeklyResetAt: Date?
    let updatedAt: Date?
    let status: UsageStatus
    let message: String?

    static func unavailable(
        tool: UsageTool,
        message: String,
        updatedAt: Date? = nil
    ) -> UsageSnapshot {
        UsageSnapshot(
            tool: tool,
            fiveHourRemainingPercent: nil,
            weeklyRemainingPercent: nil,
            fiveHourResetAt: nil,
            weeklyResetAt: nil,
            updatedAt: updatedAt,
            status: .unavailable,
            message: message
        )
    }

    static func disabled(tool: UsageTool) -> UsageSnapshot {
        unavailable(tool: tool, message: String(localized: "store.disabledInSettings"))
    }

    static func error(tool: UsageTool, message: String) -> UsageSnapshot {
        UsageSnapshot(
            tool: tool,
            fiveHourRemainingPercent: nil,
            weeklyRemainingPercent: nil,
            fiveHourResetAt: nil,
            weeklyResetAt: nil,
            updatedAt: Date(),
            status: .error,
            message: message
        )
    }
}

enum PrimaryDisplayTool: String, CaseIterable, Identifiable {
    case automatic
    case claudeCode
    case codex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic:
            String(localized: "primaryTool.automatic")
        case .claudeCode:
            String(localized: "primaryTool.claudeCode")
        case .codex:
            String(localized: "primaryTool.codex")
        }
    }

    var usageTool: UsageTool? {
        switch self {
        case .automatic:
            nil
        case .claudeCode:
            .claudeCode
        case .codex:
            .codex
        }
    }
}

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case percentOnly
    case batteryOnly
    case batteryAndPercent
    case toolAndPercent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .percentOnly:
            String(localized: "displayMode.percentOnly")
        case .batteryOnly:
            String(localized: "displayMode.batteryOnly")
        case .batteryAndPercent:
            String(localized: "displayMode.batteryAndPercent")
        case .toolAndPercent:
            String(localized: "displayMode.toolAndPercent")
        }
    }
}

enum RefreshInterval: Int, CaseIterable, Identifiable {
    case oneMinute = 60
    case threeMinutes = 180
    case fiveMinutes = 300

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .oneMinute:
            String(localized: "refreshInterval.oneMin")
        case .threeMinutes:
            String(localized: "refreshInterval.threeMin")
        case .fiveMinutes:
            String(localized: "refreshInterval.fiveMin")
        }
    }
}

struct UsageDataConfiguration {
    let claudeUsagePath: String
    let codexSessionsPath: String
    let staleInterval: TimeInterval
}
