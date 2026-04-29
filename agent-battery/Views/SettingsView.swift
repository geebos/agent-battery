import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Enabled Tools") {
                Toggle("Claude Code", isOn: $settings.claudeEnabled)
                Toggle("Codex", isOn: $settings.codexEnabled)
            }

            Section("Claude Code Setup") {
                HStack {
                    Label(settings.claudeSetupStatus.title, systemImage: claudeSetupSystemImage)
                        .foregroundStyle(claudeSetupColor)

                    Spacer()

                    Button {
                        settings.installClaudeCodeSetup()
                    } label: {
                        Label("Install / Repair", systemImage: "wrench.and.screwdriver")
                    }
                }

                if let message = settings.claudeSetupMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(settings.claudeSetupStatus == .failed ? .red : .secondary)
                }
            }

            Section("Menu Bar Display") {
                Picker("Primary tool", selection: $settings.primaryDisplayTool) {
                    ForEach(PrimaryDisplayTool.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }

                Picker("Display mode", selection: $settings.menuBarDisplayMode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Toggle("Show weekly usage", isOn: $settings.showWeeklyUsage)
            }

            Section("Refresh") {
                Picker("Refresh interval", selection: $settings.refreshInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.title).tag(interval)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Alert Thresholds") {
                Stepper(value: $settings.warningThreshold, in: (settings.criticalThreshold + 1)...95) {
                    Text("Warning below \(settings.warningThreshold)%")
                }

                Stepper(value: $settings.criticalThreshold, in: 1...(settings.warningThreshold - 1)) {
                    Text("Critical below \(settings.criticalThreshold)%")
                }
            }

            Section("Launch") {
                Toggle(
                    "Launch at Login",
                    isOn: Binding(
                        get: { settings.launchAtLoginEnabled },
                        set: { settings.setLaunchAtLoginEnabled($0) }
                    )
                )

                if let message = settings.launchAtLoginMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 520)
        .background(SettingsWindowIdentifierView())
    }

    private var claudeSetupSystemImage: String {
        switch settings.claudeSetupStatus {
        case .unknown:
            "questionmark.circle"
        case .notInstalled:
            "circle"
        case .installed:
            "checkmark.circle.fill"
        case .needsRepair:
            "exclamationmark.triangle.fill"
        case .failed:
            "xmark.octagon.fill"
        }
    }

    private var claudeSetupColor: Color {
        switch settings.claudeSetupStatus {
        case .installed:
            .green
        case .needsRepair:
            .orange
        case .failed:
            .red
        case .unknown, .notInstalled:
            .secondary
        }
    }
}
