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
        case .batteryAndPercent:
            HStack(spacing: 5) {
                Image(systemName: batterySymbol(for: snapshot.fiveHourRemainingPercent))
                    .font(.system(size: 23, weight: .regular))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: 34, height: 18, alignment: .center)

                Text(percent)
            }
            .foregroundStyle(labelColor(for: snapshot))
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
}
