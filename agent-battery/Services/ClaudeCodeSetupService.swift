import Foundation

struct ClaudeCodeSetupService {
    private let collectorScriptName = "claude-rate-limit-writer.sh"
    private let wrapperScriptName = "claude-status-line-wrapper.sh"
    private let preservedCommandName = "claude-status-line-preserved-command.txt"

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func status(configuration: ClaudeSetupConfiguration) -> ClaudeSetupStatus {
        let settingsURL = expandedFileURL(configuration.claudeSettingsPath)
        let supportURL = expandedFileURL(configuration.supportDirectoryPath)
        let wrapperURL = supportURL.appendingPathComponent(wrapperScriptName)
        let collectorURL = supportURL.appendingPathComponent(collectorScriptName)

        guard fileManager.fileExists(atPath: settingsURL.path) else {
            return .notInstalled
        }

        guard
            let settings = try? loadSettings(from: settingsURL),
            let statusLine = settings["statusLine"] as? [String: Any],
            let command = statusLine["command"] as? String
        else {
            return .notInstalled
        }

        guard command == wrapperURL.path else {
            return .notInstalled
        }

        if fileManager.fileExists(atPath: wrapperURL.path),
           fileManager.fileExists(atPath: collectorURL.path),
           collectorScript(at: collectorURL, writesTo: configuration.usageOutputPath) {
            return .installed
        }

        return .needsRepair
    }

    func install(configuration: ClaudeSetupConfiguration) throws -> ClaudeSetupResult {
        let settingsURL = expandedFileURL(configuration.claudeSettingsPath)
        let settingsDirectoryURL = settingsURL.deletingLastPathComponent()
        let supportURL = expandedFileURL(configuration.supportDirectoryPath)
        let collectorURL = supportURL.appendingPathComponent(collectorScriptName)
        let wrapperURL = supportURL.appendingPathComponent(wrapperScriptName)
        let preservedCommandURL = supportURL.appendingPathComponent(preservedCommandName)
        let usageOutputURL = expandedFileURL(configuration.usageOutputPath)

        try fileManager.createDirectory(at: supportURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: settingsDirectoryURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: usageOutputURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        var settings = try loadSettings(from: settingsURL)
        var statusLine = settings["statusLine"] as? [String: Any] ?? [:]
        let existingCommand = (statusLine["command"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let preservedCommand: String?
        if existingCommand == wrapperURL.path {
            preservedCommand = try readPreservedCommand(from: preservedCommandURL)
        } else {
            preservedCommand = preservedStatusLineCommand(
                existingCommand,
                collectorPath: collectorURL.path,
                wrapperPath: wrapperURL.path
            )
        }

        try writeCollectorScript(to: collectorURL, usageOutputPath: configuration.usageOutputPath)
        try writeWrapperScript(
            to: wrapperURL,
            collectorPath: collectorURL.path,
            preservedCommand: preservedCommand
        )
        try writePreservedCommand(preservedCommand, to: preservedCommandURL)

        if fileManager.fileExists(atPath: settingsURL.path) {
            try backupSettings(at: settingsURL)
        }

        statusLine["type"] = "command"
        statusLine["command"] = wrapperURL.path
        settings["statusLine"] = statusLine
        try writeSettings(settings, to: settingsURL)

        let message: String
        if preservedCommand == nil {
            message = String(localized: "setup.installed")
        } else {
            message = String(localized: "setup.installedPreserved")
        }

        return ClaudeSetupResult(status: .installed, message: message)
    }

    private func preservedStatusLineCommand(
        _ command: String?,
        collectorPath: String,
        wrapperPath: String
    ) -> String? {
        guard let command, !command.isEmpty else {
            return nil
        }

        if command == collectorPath || command == wrapperPath {
            return nil
        }

        return command
    }

    private func loadSettings(from url: URL) throws -> [String: Any] {
        guard fileManager.fileExists(atPath: url.path) else {
            return [:]
        }

        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            return [:]
        }

        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ClaudeSetupError.invalidSettingsJSON
        }

        return object
    }

    private func writeSettings(_ settings: [String: Any], to url: URL) throws {
        let data = try JSONSerialization.data(withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private func readPreservedCommand(from url: URL) throws -> String? {
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }

        let command = try String(contentsOf: url, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return command.isEmpty ? nil : command
    }

    private func writePreservedCommand(_ command: String?, to url: URL) throws {
        guard let command, !command.isEmpty else {
            if fileManager.fileExists(atPath: url.path) {
                try fileManager.removeItem(at: url)
            }
            return
        }

        try command.write(to: url, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func backupSettings(at url: URL) throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMddHHmmss"
        let backupURL = url.deletingLastPathComponent()
            .appendingPathComponent("settings.json.agent-battery-backup-\(formatter.string(from: Date()))")

        if !fileManager.fileExists(atPath: backupURL.path) {
            try fileManager.copyItem(at: url, to: backupURL)
        }
    }

    private func writeCollectorScript(to url: URL, usageOutputPath: String) throws {
        let script = """
        #!/bin/bash
        set -u

        OUTPUT_PATH=\(shellSingleQuoted(usageOutputPath))
        export OUTPUT_PATH

        python3 -c '
        import json
        import os
        import sys
        import time

        raw = sys.stdin.read()
        if not raw.strip():
            sys.exit(0)

        try:
            data = json.loads(raw)
        except Exception:
            sys.exit(0)

        out = {"updated_at": int(time.time())}
        rate_limits = data.get("rate_limits")

        if isinstance(rate_limits, dict):
            for key in ("five_hour", "seven_day"):
                slot = rate_limits.get(key)
                if isinstance(slot, dict):
                    out[key] = {
                        "used_percentage": slot.get("used_percentage", 0),
                        "resets_at": slot.get("resets_at", 0),
                    }

        path = os.path.expanduser(os.environ["OUTPUT_PATH"])
        directory = os.path.dirname(path)
        if directory:
            os.makedirs(directory, exist_ok=True)

        tmp = path + ".tmp"
        with open(tmp, "w") as file:
            json.dump(out, file)
        os.replace(tmp, path)
        ' 2>/dev/null
        """

        try writeExecutableScript(script, to: url)
    }

    private func collectorScript(at url: URL, writesTo usageOutputPath: String) -> Bool {
        guard let script = try? String(contentsOf: url, encoding: .utf8) else {
            return false
        }

        return script.contains("OUTPUT_PATH=\(shellSingleQuoted(usageOutputPath))")
    }

    private func writeWrapperScript(
        to url: URL,
        collectorPath: String,
        preservedCommand: String?
    ) throws {
        let preservedCommandValue = preservedCommand ?? ""
        let fallbackOutput = preservedCommand == nil ? "Claude\\n" : ""
        let script = """
        #!/bin/bash
        set -u

        COLLECTOR=\(shellSingleQuoted(collectorPath))
        PRESERVED_COMMAND=\(shellSingleQuoted(preservedCommandValue))
        TMP_FILE="${TMPDIR:-/tmp}/agent-battery-claude-status-line-$$.json"

        cleanup() {
            rm -f "$TMP_FILE"
        }
        trap cleanup EXIT

        cat > "$TMP_FILE"
        "$COLLECTOR" < "$TMP_FILE" >/dev/null 2>/dev/null || true

        if [ -n "$PRESERVED_COMMAND" ]; then
            /bin/bash -lc "$PRESERVED_COMMAND" < "$TMP_FILE"
        else
            printf '\(fallbackOutput)'
        fi
        """

        try writeExecutableScript(script, to: url)
    }

    private func writeExecutableScript(_ script: String, to url: URL) throws {
        try script.write(to: url, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: url.path)
    }

    private func expandedFileURL(_ path: String) -> URL {
        URL(fileURLWithPath: NSString(string: path).expandingTildeInPath)
    }

    private func shellSingleQuoted(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}

struct ClaudeSetupConfiguration {
    let claudeSettingsPath: String
    let supportDirectoryPath: String
    let usageOutputPath: String

    static func `default`(usageOutputPath: String = UsageDefaults.claudeUsagePath) -> ClaudeSetupConfiguration {
        ClaudeSetupConfiguration(
            claudeSettingsPath: "~/.claude/settings.json",
            supportDirectoryPath: "~/.agent-battery",
            usageOutputPath: usageOutputPath
        )
    }
}

struct ClaudeSetupResult {
    let status: ClaudeSetupStatus
    let message: String
}

enum ClaudeSetupStatus: Equatable {
    case unknown
    case notInstalled
    case installed
    case needsRepair
    case failed

    var title: String {
        switch self {
        case .unknown:
            String(localized: "setup.statusUnknown")
        case .notInstalled:
            String(localized: "setup.statusNotInstalled")
        case .installed:
            String(localized: "setup.statusInstalled")
        case .needsRepair:
            String(localized: "setup.statusNeedsRepair")
        case .failed:
            String(localized: "setup.statusFailed")
        }
    }
}

enum ClaudeSetupError: LocalizedError {
    case invalidSettingsJSON

    var errorDescription: String? {
        switch self {
        case .invalidSettingsJSON:
            String(localized: "setup.notJsonObject")
        }
    }
}
