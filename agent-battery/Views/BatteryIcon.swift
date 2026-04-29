import SwiftUI
import AppKit

struct BatteryIcon: View {
    let percent: Double?
    var height: CGFloat = 14
    var autoColor: Bool = true
    var fillColor: Color = .primary
    var lowColor: Color = .red
    var midColor: Color = .orange
    var highColor: Color = .white
    var lowEdge: Double = 16
    var midEdge: Double = 41

    var body: some View {
        if let image = renderedImage() {
            Image(nsImage: image)
        } else {
            drawing
        }
    }

    @MainActor
    private func renderedImage() -> NSImage? {
        let renderer = ImageRenderer(content: drawing)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.isTemplate = false
        return image
    }

    private var drawing: some View {
        let h = height
        let bodyW = h * 2.0
        let capW = max(1, h * 0.12)
        let capGap = max(0.5, h * 0.05)
        let lineWidth = max(1, h * 0.09)
        let cornerRadius = h * 0.28
        let innerInset = lineWidth + h * 0.08
        let innerCorner = max(0, cornerRadius - innerInset * 0.6)
        let innerW = max(0, (bodyW - innerInset * 2) * clampedRatio)
        let innerH = max(0, h - innerInset * 2)
        let totalW = bodyW + capGap + capW

        return HStack(alignment: .center, spacing: capGap) {
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(borderColor, lineWidth: lineWidth)
                .frame(width: bodyW, height: h)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: innerCorner)
                        .fill(resolvedFillColor)
                        .frame(width: innerW, height: innerH)
                        .padding(.leading, innerInset)
                }

            UnevenRoundedRectangle(
                topLeadingRadius: 0,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: h * 0.21,
                topTrailingRadius: h * 0.21
            )
            .fill(borderColor)
            .frame(width: capW, height: h * 0.42)
        }
        .frame(width: totalW, height: h)
    }

    private var clampedRatio: Double {
        min(max((percent ?? 0) / 100.0, 0), 1)
    }

    private var borderColor: Color {
        Color.white.opacity(0.46)
    }

    private var resolvedFillColor: Color {
        autoColor ? autoColorForPercent : fillColor
    }

    private var autoColorForPercent: Color {
        guard percent != nil else { return .secondary }
        let p = clampedRatio * 100
        if p < lowEdge { return lowColor }
        if p < midEdge { return midColor }
        return highColor
    }
}

#Preview {
    VStack(spacing: 12) {
        BatteryIcon(percent: 95)
        BatteryIcon(percent: 60)
        BatteryIcon(percent: 30)
        BatteryIcon(percent: 8)
        BatteryIcon(percent: nil)
        BatteryIcon(percent: 60, autoColor: false, fillColor: .blue)
        BatteryIcon(percent: 60, height: 22)
    }
    .padding()
}
