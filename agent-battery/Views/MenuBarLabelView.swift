import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: UsageStore

    var body: some View {
        let snapshot = store.primarySnapshot
        let percent = UsageFormatters.percentText(snapshot.fiveHourRemainingPercent)

        switch settings.menuBarDisplayMode {
        case .percentOnly:
            Text(percent)
                .foregroundStyle(labelColor(for: snapshot))
        case .batteryOnly:
            BatteryIcon(percent: snapshot.fiveHourRemainingPercent, height: 12)
        case .batteryAndPercent:
            HStack(spacing: 4) {
                BatteryIcon(percent: snapshot.fiveHourRemainingPercent, height: 12)

                Text(percent)
                    .foregroundStyle(labelColor(for: snapshot))
            }
            .fixedSize()
        case .toolAndPercent:
            Text("\(snapshot.tool.shortName) \(percent)")
                .foregroundStyle(labelColor(for: snapshot))
        }
    }

    private func batterySymbol(for percent: Double?) -> String {
        guard let percent else {
            return "battery.0"
        }

        switch percent {
        case 76...:
            return "battery.100"
        case 41...:
            return "battery.75"
        case 16...:
            return "battery.25"
        default:
            return "battery.0"
        }
    }

    private func labelColor(for snapshot: UsageSnapshot) -> Color {
        switch store.level(for: snapshot) {
        case .normal:
            return .primary
        case .warning:
            return .orange
        case .critical:
            return .red
        case .unavailable:
            return .secondary
        }
    }

    private func batteryColor(for snapshot: UsageSnapshot) -> Color {
        switch store.level(for: snapshot) {
        case .normal:
            return .green
        case .warning:
            return .orange
        case .critical:
            return .red
        case .unavailable:
            return .secondary
        }
    }
}
