import AppKit
import SwiftUI

struct MenuBarLabelView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var store: UsageStore

    var body: some View {
        let snapshot = store.primarySnapshot
        let percent = UsageFormatters.percentText(snapshot.fiveHourRemainingPercent)
        let showsPercent = settings.showMenuBarPercent
        let color = labelColor(for: snapshot)

        switch settings.menuBarDisplayMode {
        case .percent:
            MenuBarText(text: percent, color: color)
        case .battery:
            if showsPercent {
                Image(nsImage: batteryWithPercentImage(snapshot: snapshot, percent: percent, color: color))
            } else {
                batteryIcon(snapshot: snapshot)
            }
        case .tool:
            if showsPercent {
                MenuBarText(text: "\(snapshot.tool.shortName) \(percent)", color: color)
            } else {
                MenuBarText(text: snapshot.tool.shortName, color: color)
            }
        }
    }

    private func batteryIcon(snapshot: UsageSnapshot) -> some View {
        BatteryIcon(
            percent: snapshot.fiveHourRemainingPercent,
            height: 12,
            autoColor: settings.colorByUsage,
            fillColor: .white,
            lowColor: settings.usageColorLow,
            midColor: settings.usageColorMid,
            highColor: settings.usageColorHigh,
            lowEdge: Double(settings.criticalThreshold),
            midEdge: Double(settings.warningThreshold)
        )
    }

    @MainActor
    private func batteryWithPercentImage(snapshot: UsageSnapshot, percent: String, color: Color) -> NSImage {
        let height: CGFloat = 12
        let spacing: CGFloat = 4
        let renderer = ImageRenderer(content: batteryIcon(snapshot: snapshot))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        let batteryImage = renderer.nsImage ?? NSImage(size: NSSize(width: height * 2.4, height: height))
        let batterySize = batteryImage.size

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuBarFont(ofSize: 0),
            .foregroundColor: NSColor(color)
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
        image.isTemplate = false
        return image
    }
}

private struct MenuBarText: View {
    let text: String
    let color: Color

    var body: some View {
        Image(nsImage: renderedImage())
    }

    private func renderedImage() -> NSImage {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.menuBarFont(ofSize: 0),
            .foregroundColor: NSColor(color)
        ]
        let attrString = NSAttributedString(string: text, attributes: attrs)
        let size = attrString.size()
        let drawSize = NSSize(width: ceil(size.width), height: ceil(size.height))
        let image = NSImage(size: drawSize, flipped: false) { rect in
            attrString.draw(in: rect)
            return true
        }
        image.isTemplate = false
        return image
    }
}

extension MenuBarLabelView {
    fileprivate func labelColor(for snapshot: UsageSnapshot) -> Color {
        guard let percent = snapshot.fiveHourRemainingPercent else {
            return .secondary
        }

        let usesUsageColor: Bool
        switch settings.menuBarDisplayMode {
        case .percent, .tool:
            usesUsageColor = settings.colorByUsage
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
}
