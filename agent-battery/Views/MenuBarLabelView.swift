import AppKit
import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: UsageStore

    var body: some View {
        if settings.primaryDisplayTool == .sideBySide {
            sideBySideLabel
        } else {
            label(for: store.primarySnapshot)
        }
    }

    @ViewBuilder
    private func label(for snapshot: UsageSnapshot) -> some View {
        let percent = UsageFormatters.percentText(snapshot.menuBarRemainingPercent)
        let showsPercent = settings.showMenuBarPercent
        let color = labelColor(for: snapshot)
        let isTemplate = settings.followsSystemColor

        switch settings.menuBarDisplayMode {
        case .percent:
            MenuBarText(text: percent, color: color, isTemplate: isTemplate)
        case .battery:
            if showsPercent {
                Image(nsImage: batteryWithPercentImage(snapshot: snapshot, percent: percent, color: color, isTemplate: isTemplate))
                    .renderingMode(isTemplate ? .template : .original)
            } else {
                Image(nsImage: renderedBatteryImage(snapshot: snapshot, height: 12, isTemplate: isTemplate))
                    .renderingMode(isTemplate ? .template : .original)
            }
        case .tool:
            if showsPercent {
                MenuBarText(text: "\(snapshot.tool.shortName) \(percent)", color: color, isTemplate: isTemplate)
            } else {
                MenuBarText(text: snapshot.tool.shortName, color: color, isTemplate: isTemplate)
            }
        }
    }

    @ViewBuilder
    private var sideBySideLabel: some View {
        let snapshots = sideBySideSnapshots
        let isTemplate = settings.followsSystemColor

        switch settings.menuBarDisplayMode {
        case .percent:
            Image(nsImage: sideBySidePercentImage(snapshots: snapshots, isTemplate: isTemplate))
                .renderingMode(isTemplate ? .template : .original)
        case .battery:
            if settings.showMenuBarPercent {
                Image(nsImage: sideBySideBatteryWithPercentImage(snapshots: snapshots, isTemplate: isTemplate))
                    .renderingMode(isTemplate ? .template : .original)
            } else {
                Image(nsImage: sideBySideBatteryImage(snapshots: snapshots, isTemplate: isTemplate))
                    .renderingMode(isTemplate ? .template : .original)
            }
        case .tool:
            Image(nsImage: sideBySideToolImage(snapshots: snapshots, isTemplate: isTemplate))
                .renderingMode(isTemplate ? .template : .original)
        }
    }

    private var sideBySideSnapshots: [UsageSnapshot] {
        Self.sideBySideTools.map { store.snapshot(for: $0) }
    }

    private static let sideBySideTools: [UsageTool] = [.claudeCode, .codex]

    private func batteryIcon(
        snapshot: UsageSnapshot,
        height: CGFloat = 12,
        isTemplate: Bool = false,
        rendersAsImage: Bool = true
    ) -> some View {
        BatteryIcon(
            percent: snapshot.menuBarRemainingPercent,
            height: height,
            autoColor: settings.colorsByUsage,
            fillColor: .white,
            lowColor: settings.usageColorLow,
            midColor: settings.usageColorMid,
            highColor: settings.usageColorHigh,
            lowEdge: Double(settings.criticalThreshold),
            midEdge: Double(settings.warningThreshold),
            isTemplate: isTemplate,
            rendersAsImage: rendersAsImage
        )
    }

    @MainActor
    private func batteryWithPercentImage(
        snapshot: UsageSnapshot,
        percent: String,
        color: Color,
        isTemplate: Bool = false
    ) -> NSImage {
        let height: CGFloat = 12
        let spacing: CGFloat = 4
        let batteryImage = renderedBatteryImage(snapshot: snapshot, height: height, isTemplate: isTemplate)
        let batterySize = batteryImage.size

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuBarFont(ofSize: 0),
            .foregroundColor: isTemplate ? NSColor.black : NSColor(color)
        ]
        let attrString = NSAttributedString(string: percent, attributes: attrs)
        let textSize = attrString.size()

        let totalWidth = ceil(batterySize.width + spacing + textSize.width)
        let totalHeight = ceil(max(batterySize.height, textSize.height))

        let image = NSImage(size: NSSize(width: totalWidth, height: totalHeight), flipped: false) { _ in
            let batteryY = (totalHeight - batterySize.height) / 2
            batteryImage.draw(in: NSRect(x: 0, y: batteryY, width: batterySize.width, height: batterySize.height))
            let textY = (totalHeight - textSize.height) / 2
            attrString.draw(at: NSPoint(x: batterySize.width + spacing, y: textY))
            return true
        }
        image.isTemplate = isTemplate
        return image
    }
}

private enum MenuBarSideBySideMetrics {
    static let font = NSFont.menuBarFont(ofSize: 9)
    static let rowSpacing: CGFloat = 0
    static let batteryHeight: CGFloat = 8
    static let batteryTextSpacing: CGFloat = 3
    static let toolPercentSpacing: CGFloat = 4
}

private struct MenuBarTextImageRow {
    let text: String
    let color: Color
}

private struct MenuBarToolImageRow {
    let name: String
    let percent: String?
    let color: Color
}

private struct MenuBarText: View {
    let text: String
    let color: Color
    var isTemplate: Bool = false

    var body: some View {
        Image(nsImage: renderedImage())
            .renderingMode(isTemplate ? .template : .original)
    }

    private func renderedImage() -> NSImage {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuBarFont(ofSize: 0),
            .foregroundColor: isTemplate ? NSColor.black : NSColor(color)
        ]
        let attrString = NSAttributedString(string: text, attributes: attrs)
        let size = attrString.size()
        let drawSize = NSSize(width: ceil(size.width), height: ceil(size.height))
        let image = NSImage(size: drawSize, flipped: false) { rect in
            attrString.draw(in: rect)
            return true
        }
        image.isTemplate = isTemplate
        return image
    }
}

extension MenuBarLabelView {
    fileprivate func labelColor(for snapshot: UsageSnapshot) -> Color {
        guard let percent = snapshot.menuBarRemainingPercent else {
            return .secondary
        }

        let usesUsageColor: Bool
        switch settings.menuBarDisplayMode {
        case .percent, .tool:
            usesUsageColor = settings.colorsByUsage
        case .battery:
            usesUsageColor = false
        }

        guard usesUsageColor else { return .white }

        if percent < Double(settings.criticalThreshold) {
            return settings.usageColorLow
        }
        if percent < Double(settings.warningThreshold) {
            return settings.usageColorMid
        }
        return settings.usageColorHigh
    }

    @MainActor
    fileprivate func sideBySidePercentImage(snapshots: [UsageSnapshot], isTemplate: Bool = false) -> NSImage {
        textRowsImage(
            snapshots.map { snapshot in
                MenuBarTextImageRow(
                    text: UsageFormatters.percentText(snapshot.menuBarRemainingPercent),
                    color: labelColor(for: snapshot)
                )
            },
            isTemplate: isTemplate
        )
    }

    @MainActor
    fileprivate func sideBySideBatteryImage(snapshots: [UsageSnapshot], isTemplate: Bool = false) -> NSImage {
        let batteryImages = snapshots.map {
            renderedBatteryImage(
                snapshot: $0,
                height: MenuBarSideBySideMetrics.batteryHeight,
                isTemplate: isTemplate
            )
        }
        let rowHeight = ceil(maxValue(batteryImages.map { $0.size.height }))
        let width = ceil(maxValue(batteryImages.map { $0.size.width }))

        return renderedRowsImage(
            rowCount: batteryImages.count,
            width: width,
            rowHeight: rowHeight,
            isTemplate: isTemplate
        ) { index, y, rowHeight in
            let batterySize = batteryImages[index].size
            batteryImages[index].draw(
                in: NSRect(
                    x: 0,
                    y: y + (rowHeight - batterySize.height) / 2,
                    width: batterySize.width,
                    height: batterySize.height
                )
            )
        }
    }

    @MainActor
    fileprivate func sideBySideBatteryWithPercentImage(
        snapshots: [UsageSnapshot],
        isTemplate: Bool = false
    ) -> NSImage {
        let batteryImages = snapshots.map {
            renderedBatteryImage(
                snapshot: $0,
                height: MenuBarSideBySideMetrics.batteryHeight,
                isTemplate: isTemplate
            )
        }
        let textRows = snapshots.map { snapshot in
            attributedString(
                UsageFormatters.percentText(snapshot.menuBarRemainingPercent),
                color: labelColor(for: snapshot),
                isTemplate: isTemplate
            )
        }
        let textSizes = textRows.map { $0.size() }
        let batteryWidth = ceil(maxValue(batteryImages.map { $0.size.width }))
        let batteryHeight = ceil(maxValue(batteryImages.map { $0.size.height }))
        let textWidth = ceil(maxValue(textSizes.map { $0.width }))
        let textHeight = ceil(maxValue(textSizes.map { $0.height }))
        let rowHeight = max(batteryHeight, textHeight)
        let width = batteryWidth + MenuBarSideBySideMetrics.batteryTextSpacing + textWidth

        return renderedRowsImage(
            rowCount: snapshots.count,
            width: width,
            rowHeight: rowHeight,
            isTemplate: isTemplate
        ) { index, y, rowHeight in
            let batterySize = batteryImages[index].size
            batteryImages[index].draw(
                in: NSRect(
                    x: 0,
                    y: y + (rowHeight - batterySize.height) / 2,
                    width: batterySize.width,
                    height: batterySize.height
                )
            )

            let textSize = textSizes[index]
            textRows[index].draw(
                at: NSPoint(
                    x: batteryWidth + MenuBarSideBySideMetrics.batteryTextSpacing,
                    y: y + (rowHeight - textSize.height) / 2
                )
            )
        }
    }

    @MainActor
    fileprivate func sideBySideToolImage(snapshots: [UsageSnapshot], isTemplate: Bool = false) -> NSImage {
        let rows = snapshots.map { snapshot in
            MenuBarToolImageRow(
                name: snapshot.tool.shortName,
                percent: settings.showMenuBarPercent ? UsageFormatters.percentText(snapshot.menuBarRemainingPercent) : nil,
                color: labelColor(for: snapshot)
            )
        }

        guard settings.showMenuBarPercent else {
            return textRowsImage(
                rows.map { MenuBarTextImageRow(text: $0.name, color: $0.color) },
                isTemplate: isTemplate
            )
        }

        let nameRows = rows.map { attributedString($0.name, color: $0.color, isTemplate: isTemplate) }
        let percentRows = rows.map { attributedString($0.percent ?? "", color: $0.color, isTemplate: isTemplate) }
        let nameSizes = nameRows.map { $0.size() }
        let percentSizes = percentRows.map { $0.size() }
        let nameWidth = ceil(maxValue(nameSizes.map { $0.width }))
        let percentWidth = ceil(maxValue(percentSizes.map { $0.width }))
        let rowHeight = ceil(max(maxValue(nameSizes.map { $0.height }), maxValue(percentSizes.map { $0.height })))
        let width = nameWidth + MenuBarSideBySideMetrics.toolPercentSpacing + percentWidth

        return renderedRowsImage(
            rowCount: rows.count,
            width: width,
            rowHeight: rowHeight,
            isTemplate: isTemplate
        ) { index, y, rowHeight in
            let nameSize = nameSizes[index]
            nameRows[index].draw(
                at: NSPoint(
                    x: 0,
                    y: y + (rowHeight - nameSize.height) / 2
                )
            )

            let percentSize = percentSizes[index]
            percentRows[index].draw(
                at: NSPoint(
                    x: nameWidth + MenuBarSideBySideMetrics.toolPercentSpacing,
                    y: y + (rowHeight - percentSize.height) / 2
                )
            )
        }
    }

    @MainActor
    fileprivate func renderedBatteryImage(snapshot: UsageSnapshot, height: CGFloat, isTemplate: Bool = false) -> NSImage {
        let renderer = ImageRenderer(
            content: batteryIcon(
                snapshot: snapshot,
                height: height,
                isTemplate: isTemplate,
                rendersAsImage: false
            )
        )
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let image = renderer.nsImage ?? NSImage(size: NSSize(width: height * 2.4, height: height))
        image.isTemplate = false
        return image
    }

    fileprivate func textRowsImage(_ rows: [MenuBarTextImageRow], isTemplate: Bool = false) -> NSImage {
        let attributedRows = rows.map { attributedString($0.text, color: $0.color, isTemplate: isTemplate) }
        let sizes = attributedRows.map { $0.size() }
        let rowHeight = ceil(maxValue(sizes.map { $0.height }))
        let width = ceil(maxValue(sizes.map { $0.width }))

        return renderedRowsImage(
            rowCount: rows.count,
            width: width,
            rowHeight: rowHeight,
            isTemplate: isTemplate
        ) { index, y, rowHeight in
            let size = sizes[index]
            attributedRows[index].draw(
                at: NSPoint(
                    x: 0,
                    y: y + (rowHeight - size.height) / 2
                )
            )
        }
    }

    fileprivate func renderedRowsImage(
        rowCount: Int,
        width: CGFloat,
        rowHeight: CGFloat,
        isTemplate: Bool = false,
        drawRow: @escaping (Int, CGFloat, CGFloat) -> Void
    ) -> NSImage {
        let normalizedRowCount = max(rowCount, 1)
        let normalizedWidth = max(ceil(width), 1)
        let normalizedRowHeight = max(ceil(rowHeight), 1)
        let totalHeight = normalizedRowHeight * CGFloat(normalizedRowCount)
            + MenuBarSideBySideMetrics.rowSpacing * CGFloat(max(normalizedRowCount - 1, 0))
        let image = NSImage(size: NSSize(width: normalizedWidth, height: totalHeight), flipped: false) { _ in
            for index in 0..<rowCount {
                let y = totalHeight
                    - CGFloat(index + 1) * normalizedRowHeight
                    - CGFloat(index) * MenuBarSideBySideMetrics.rowSpacing
                drawRow(index, y, normalizedRowHeight)
            }
            return true
        }
        image.isTemplate = isTemplate
        return image
    }

    fileprivate func attributedString(_ text: String, color: Color, isTemplate: Bool = false) -> NSAttributedString {
        NSAttributedString(
            string: text,
            attributes: [
                .font: MenuBarSideBySideMetrics.font,
                .foregroundColor: isTemplate ? NSColor.black : NSColor(color),
            ]
        )
    }

    fileprivate func maxValue(_ values: [CGFloat]) -> CGFloat {
        values.max() ?? 1
    }
}
