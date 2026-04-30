import AppKit
import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: UsageStore
    @Environment(\.openSettings) private var openSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if store.enabledTools.isEmpty {
                Text("menu.noToolsEnabled")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 20)
            } else {
                ForEach(store.enabledTools) { tool in
                    UsageToolCardView(
                        snapshot: store.snapshot(for: tool),
                        showWeeklyUsage: settings.showWeeklyUsage,
                        warningThreshold: settings.warningThreshold,
                        criticalThreshold: settings.criticalThreshold
                    )
                }
            }

            Divider()

            HStack {
                Button {
                    SettingsWindowPresenter.show(dismissingMenuBarPanel: {
                        dismiss()
                    }) {
                        openSettings()
                    }
                } label: {
                    Label("menu.settings", systemImage: "gearshape")
                }

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("menu.quit", systemImage: "power")
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("menu.appName")
                .font(.headline)

            Spacer()

            StatusPill(level: store.level(for: store.primarySnapshot))
        }
    }
}

private struct StatusPill: View {
    let level: UsageLevel

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.16), in: Capsule())
            .foregroundStyle(tint)
    }

    private var title: LocalizedStringKey {
        switch level {
        case .normal:
            "menu.statusOk"
        case .warning:
            "menu.statusLow"
        case .critical:
            "menu.statusCritical"
        case .unavailable:
            "menu.statusNoData"
        }
    }

    private var tint: Color {
        switch level {
        case .normal:
            .secondary
        case .warning:
            .orange
        case .critical:
            .red
        case .unavailable:
            .secondary
        }
    }
}
