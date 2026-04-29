import AppKit
import SwiftUI

struct MenuBarPanelView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: UsageStore
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if store.enabledTools.isEmpty {
                Text("No tools enabled.")
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
                    SettingsWindowPresenter.show {
                        openSettings()
                    }
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }

                Spacer()

                Button {
                    NSApplication.shared.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                }
            }
            .buttonStyle(.borderless)
        }
        .padding(14)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Agent Battery")
                    .font(.headline)
                Text(store.lastRefreshAt.map { UsageFormatters.updatedText($0, status: .available) } ?? "Waiting for first refresh")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

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

    private var title: String {
        switch level {
        case .normal:
            "OK"
        case .warning:
            "Low"
        case .critical:
            "Critical"
        case .unavailable:
            "No Data"
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
