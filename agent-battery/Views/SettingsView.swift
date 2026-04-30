import Foundation
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
                Picker("settings.displayMode", selection: $settings.menuBarDisplayMode) {
                    ForEach(MenuBarDisplayMode.allCases) { mode in
                        HStack(spacing: 12) {
                            Text(mode.title)
                                .frame(width: 80, alignment: .leading)
                            MenuBarModePreviewRow(settings: settings, mode: mode)
                        }
                        .tag(mode)
                    }
                }
                .pickerStyle(.radioGroup)

                Picker("settings.showSection", selection: $settings.primaryDisplayTool) {
                    Text("settings.showLowest").tag(PrimaryDisplayTool.automatic)
                    Text("settings.showClaude").tag(PrimaryDisplayTool.claudeCode)
                    Text("settings.showCodex").tag(PrimaryDisplayTool.codex)
                }
                .pickerStyle(.radioGroup)

                if settings.menuBarDisplayMode.supportsPercentToggle {
                    Toggle("settings.showPercent", isOn: $settings.showMenuBarPercent)
                }

                Toggle("settings.colorByUsage", isOn: $settings.colorByUsage)

                if settings.colorByUsage {
                    UsageColorBar(settings: settings)
                }

                Toggle("settings.showWeekly", isOn: $settings.showWeeklyUsage)
            }

            Section("settings.sectionRefresh") {
                Picker("settings.refreshInterval", selection: refreshIntervalSelection) {
                    ForEach(RefreshInterval.allCases) { interval in
                        Text(interval.title).tag(interval)
                    }
                }
                .pickerStyle(.segmented)
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

            Section("settings.sectionAbout") {
                HStack {
                    Text("settings.version")
                    Spacer()
                    Text(Self.appVersionDisplay)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 520)
        .background(SettingsWindowIdentifierView())
    }

    private var refreshIntervalSelection: Binding<RefreshInterval> {
        Binding(
            get: {
                settings.refreshInterval
            },
            set: { newValue in
                guard settings.refreshInterval != newValue else {
                    return
                }

                DispatchQueue.main.async {
                    settings.refreshInterval = newValue
                }
            }
        )
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

    private static let appVersionDisplay: String = {
        let info = Bundle.main.infoDictionary
        let version = (info?["CFBundleShortVersionString"] as? String) ?? ""
        let build = (info?["CFBundleVersion"] as? String) ?? ""
        if version.isEmpty && build.isEmpty {
            return "-"
        }
        if build.isEmpty {
            return "v\(version)"
        }
        if version.isEmpty {
            return "(\(build))"
        }
        return "v\(version) (\(build))"
    }()

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
