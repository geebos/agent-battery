import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Section("settings.sectionEnabledTools") {
                Toggle("tool.claudeCodeName", isOn: $settings.claudeEnabled)
                Toggle("tool.codexName", isOn: $settings.codexEnabled)
            }

            Section("settings.sectionClaudeSetup") {
                HStack {
                    Label(settings.claudeSetupStatus.title, systemImage: claudeSetupSystemImage)
                        .foregroundStyle(claudeSetupColor)

                    Spacer()

                    Button {
                        settings.installClaudeCodeSetup()
                    } label: {
                        Label("settings.installRepair", systemImage: "wrench.and.screwdriver")
                    }
                }

                if let message = settings.claudeSetupMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(settings.claudeSetupStatus == .failed ? .red : .secondary)
                }
            }

            Section("settings.sectionMenuBarDisplay") {
                Picker("settings.primaryTool", selection: $settings.primaryDisplayTool) {
                    ForEach(PrimaryDisplayTool.allCases) { option in
                        Text(option.title).tag(option)
                    }
                }

                Picker("settings.displayMode", selection: $settings.menuBarDisplayMode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }

                Toggle("settings.showWeekly", isOn: $settings.showWeeklyUsage)
            }

            Section("settings.sectionRefresh") {
                Picker("settings.refreshInterval", selection: $settings.refreshInterval) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.title).tag(interval)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("settings.sectionAlertThresholds") {
                Stepper(value: $settings.warningThreshold, in: (settings.criticalThreshold + 1)...95) {
                    Text(verbatim: String(format: NSLocalizedString("settings.warningBelow", comment: ""), settings.warningThreshold))
                }

                Stepper(value: $settings.criticalThreshold, in: 1...(settings.warningThreshold - 1)) {
                    Text(verbatim: String(format: NSLocalizedString("settings.criticalBelow", comment: ""), settings.criticalThreshold))
                }
            }

            Section("settings.sectionLaunch") {
                Toggle(
                    "settings.launchAtLogin",
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
