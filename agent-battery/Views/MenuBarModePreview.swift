import SwiftUI

struct MenuBarModePreview: View {
    @ObservedObject var settings: AppSettings
    let mode: MenuBarDisplayMode
    let percent: Double
    let toolShortName: String

    var body: some View {
        HStack(spacing: 4) {
            switch mode {
            case .percent:
                Text(percentText)
                    .foregroundStyle(textColor)
            case .battery:
                BatteryIcon(
                    percent: percent,
                    height: 12,
                    autoColor: settings.colorByUsage,
                    fillColor: .white,
                    lowColor: settings.usageColorLow,
                    midColor: settings.usageColorMid,
                    highColor: settings.usageColorHigh,
                    lowEdge: Double(settings.criticalThreshold),
                    midEdge: Double(settings.warningThreshold)
                )
                Text(percentText)
                    .foregroundStyle(textColor)
            case .tool:
                Text("\(toolShortName) \(percentText)")
                    .foregroundStyle(textColor)
            }
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.black.opacity(0.55))
        )
    }

    private var percentText: String {
        "\(Int(percent))%"
    }

    private var textColor: Color {
        switch mode {
        case .battery:
            return .white
        case .percent, .tool:
            guard settings.colorByUsage else { return .white }
            if percent < Double(settings.criticalThreshold) {
                return settings.usageColorLow
            }
            if percent < Double(settings.warningThreshold) {
                return settings.usageColorMid
            }
            return settings.usageColorHigh
        }
    }
}

struct MenuBarModePreviewRow: View {
    @ObservedObject var settings: AppSettings
    let mode: MenuBarDisplayMode

    private static let samples: [Double] = [8, 30, 80]
    private static let sideBySideSamples: [SideBySidePreviewGroup] = [
        SideBySidePreviewGroup(
            id: 0,
            samples: [
                SideBySidePreviewSample(tool: .claudeCode, percent: 8),
                SideBySidePreviewSample(tool: .codex, percent: 12),
            ]
        ),
        SideBySidePreviewGroup(
            id: 1,
            samples: [
                SideBySidePreviewSample(tool: .claudeCode, percent: 30),
                SideBySidePreviewSample(tool: .codex, percent: 35),
            ]
        ),
        SideBySidePreviewGroup(
            id: 2,
            samples: [
                SideBySidePreviewSample(tool: .claudeCode, percent: 80),
                SideBySidePreviewSample(tool: .codex, percent: 75),
            ]
        ),
    ]

    var body: some View {
        if settings.primaryDisplayTool == .sideBySide {
            HStack(spacing: 6) {
                ForEach(Self.sideBySideSamples) { group in
                    MenuBarSideBySideModePreview(
                        settings: settings,
                        mode: mode,
                        samples: group.samples
                    )
                }
            }
        } else {
            HStack(spacing: 6) {
                ForEach(Self.samples, id: \.self) { value in
                    MenuBarModePreview(
                        settings: settings,
                        mode: mode,
                        percent: value,
                        toolShortName: previewToolShortName
                    )
                }
            }
        }
    }

    private var previewToolShortName: String {
        let tool = settings.primaryDisplayTool.usageTool ?? .claudeCode
        return tool.shortName
    }
}

private struct MenuBarSideBySideModePreview: View {
    @ObservedObject var settings: AppSettings
    let mode: MenuBarDisplayMode
    let samples: [SideBySidePreviewSample]

    var body: some View {
        Group {
            switch mode {
            case .percent:
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(samples) { sample in
                        Text(percentText(sample.percent))
                            .foregroundStyle(textColor(for: sample.percent))
                    }
                }
            case .battery:
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(samples) { sample in
                        HStack(spacing: 3) {
                            BatteryIcon(
                                percent: sample.percent,
                                height: 9,
                                autoColor: settings.colorByUsage,
                                fillColor: .white,
                                lowColor: settings.usageColorLow,
                                midColor: settings.usageColorMid,
                                highColor: settings.usageColorHigh,
                                lowEdge: Double(settings.criticalThreshold),
                                midEdge: Double(settings.warningThreshold)
                            )
                            Text(percentText(sample.percent))
                                .foregroundStyle(.white)
                        }
                    }
                }
            case .tool:
                Grid(alignment: .leading, horizontalSpacing: 4, verticalSpacing: 1) {
                    ForEach(samples) { sample in
                        GridRow {
                            Text(sample.tool.shortName)
                            Text(percentText(sample.percent))
                        }
                        .foregroundStyle(textColor(for: sample.percent))
                    }
                }
            }
        }
        .font(.system(size: 10, weight: .medium))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.black.opacity(0.55))
        )
    }

    private func percentText(_ percent: Double) -> String {
        "\(Int(percent))%"
    }

    private func textColor(for percent: Double) -> Color {
        switch mode {
        case .battery:
            return .white
        case .percent, .tool:
            guard settings.colorByUsage else { return .white }
            if percent < Double(settings.criticalThreshold) {
                return settings.usageColorLow
            }
            if percent < Double(settings.warningThreshold) {
                return settings.usageColorMid
            }
            return settings.usageColorHigh
        }
    }
}

private struct SideBySidePreviewGroup: Identifiable {
    let id: Int
    let samples: [SideBySidePreviewSample]
}

private struct SideBySidePreviewSample: Identifiable {
    let tool: UsageTool
    let percent: Double

    var id: UsageTool { tool }
}
