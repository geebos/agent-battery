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
            "Claude Code"
        case .codex:
            "Codex"
        }
    }

    var shortName: String {
        switch self {
        case .claudeCode:
            "Claude"
        case .codex:
            "Codex"
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
            "Available"
        case .unavailable:
            "Unavailable"
        case .stale:
            "Stale"
        case .error:
            "Error"
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
        unavailable(tool: tool, message: "Disabled in Settings.")
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
            "Lowest remaining"
        case .claudeCode:
            "Claude Code"
        case .codex:
            "Codex"
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
    case batteryAndPercent
    case toolAndPercent

    var id: String { rawValue }

    var title: String {
        switch self {
        case .percentOnly:
            "Percent only"
        case .batteryAndPercent:
            "Battery + percent"
        case .toolAndPercent:
            "Tool + percent"
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
            "1 min"
        case .threeMinutes:
            "3 min"
        case .fiveMinutes:
            "5 min"
        }
    }
}

struct UsageDataConfiguration {
    let claudeUsagePath: String
    let codexSessionsPath: String
    let staleInterval: TimeInterval
}
