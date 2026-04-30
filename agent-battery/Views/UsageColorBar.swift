import AppKit
import SwiftUI

struct UsageColorBar: View {
    @ObservedObject var settings: AppSettings

    @State private var draggingKind: ThumbKind?

    private let trackHeight: CGFloat = 6
    private let thumbWidth: CGFloat = 18
    private let thumbRectHeight: CGFloat = 14
    private let thumbTipHeight: CGFloat = 6
    private let labelGap: CGFloat = 4
    private let labelHeight: CGFloat = 14
    private var thumbTotalHeight: CGFloat { thumbRectHeight + thumbTipHeight }

    enum ThumbKind: CaseIterable, Identifiable {
        case low, mid, high
        var id: Self { self }

        var isFixed: Bool { self == .high }
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let trackY = thumbTotalHeight + trackHeight / 2

            ZStack(alignment: .topLeading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: width, height: trackHeight)
                    .position(x: width / 2, y: trackY)

                ForEach(ThumbKind.allCases) { kind in
                    thumbView(kind, in: width)
                }

                ForEach(ThumbKind.allCases) { kind in
                    valueLabel(kind, in: width)
                }
            }
            .frame(width: width, height: rowHeight)
        }
        .frame(height: rowHeight)
    }

    private var rowHeight: CGFloat {
        thumbTotalHeight + trackHeight + labelGap + labelHeight
    }

    @ViewBuilder
    private func valueLabel(_ kind: ThumbKind, in width: CGFloat) -> some View {
        let value = currentValue(for: kind)
        let centerX = width * CGFloat(value) / 100
        let labelY = thumbTotalHeight + trackHeight + labelGap + labelHeight / 2

        Text("\(value)")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(.secondary)
            .fixedSize()
            .position(x: clampedLabelX(centerX, width: width), y: labelY)
            .allowsHitTesting(false)
    }

    private func clampedLabelX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        let half: CGFloat = 14
        return min(max(x, half), width - half)
    }

    @ViewBuilder
    private func thumbView(_ kind: ThumbKind, in width: CGFloat) -> some View {
        let value = currentValue(for: kind)
        let centerX = width * CGFloat(value) / 100
        let cursor: PointerStyle = (draggingKind == kind) ? .grabActive : .default

        Thumb(color: color(for: kind))
            .frame(width: thumbWidth, height: thumbTotalHeight)
            .pointerStyle(cursor)
            .position(x: centerX, y: thumbTotalHeight / 2)
            .gesture(kind.isFixed ? nil : dragGesture(for: kind, width: width))
            .onTapGesture {
                presentColorPanel(for: kind)
            }
    }

    private func dragGesture(for kind: ThumbKind, width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                draggingKind = kind
                let pct = Int(((value.location.x / width) * 100).rounded())
                let bounds = bounds(for: kind)
                let clamped = max(bounds.lowerBound, min(bounds.upperBound, pct))
                setValue(clamped, for: kind)
            }
            .onEnded { _ in
                draggingKind = nil
            }
    }

    private func presentColorPanel(for kind: ThumbKind) {
        ColorPanelController.shared.present(
            initial: NSColor(color(for: kind))
        ) { newColor in
            let hex = Color(nsColor: newColor).hexString
            switch kind {
            case .low: settings.usageColorLowHex = hex
            case .mid: settings.usageColorMidHex = hex
            case .high: settings.usageColorHighHex = hex
            }
        }
    }

    private func currentValue(for kind: ThumbKind) -> Int {
        switch kind {
        case .low: settings.criticalThreshold
        case .mid: settings.warningThreshold
        case .high: 100
        }
    }

    private func setValue(_ v: Int, for kind: ThumbKind) {
        switch kind {
        case .low: settings.criticalThreshold = v
        case .mid: settings.warningThreshold = v
        case .high: break
        }
    }

    private func bounds(for kind: ThumbKind) -> ClosedRange<Int> {
        switch kind {
        case .low: 1...(settings.warningThreshold - 1)
        case .mid: (settings.criticalThreshold + 1)...99
        case .high: 100...100
        }
    }

    private func color(for kind: ThumbKind) -> Color {
        switch kind {
        case .low: settings.usageColorLow
        case .mid: settings.usageColorMid
        case .high: settings.usageColorHigh
        }
    }
}

private final class ColorPanelController: NSObject {
    static let shared = ColorPanelController()

    private var callback: ((NSColor) -> Void)?
    private var closeObserver: NSObjectProtocol?

    func present(initial: NSColor, callback: @escaping (NSColor) -> Void) {
        self.callback = callback
        let panel = NSColorPanel.shared
        panel.mode = .RGB
        panel.showsAlpha = false
        panel.color = initial
        panel.setTarget(self)
        panel.setAction(#selector(colorChanged(_:)))
        panel.makeKeyAndOrderFront(nil)

        if closeObserver == nil {
            closeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: panel,
                queue: .main
            ) { [weak self] _ in
                self?.detach()
            }
        }
    }

    private func detach() {
        callback = nil
        let panel = NSColorPanel.shared
        panel.setTarget(nil)
        panel.setAction(nil)
    }

    @objc private func colorChanged(_ sender: NSColorPanel) {
        guard sender.isVisible else { return }
        callback?(sender.color)
    }
}

private struct Thumb: View {
    let color: Color

    var body: some View {
        ThumbShape(tipHeight: 6)
            .fill(color)
            .overlay(ThumbShape(tipHeight: 6).stroke(Color.white, lineWidth: 1.2))
            .shadow(color: .black.opacity(0.35), radius: 2, x: 0, y: 1)
            .contentShape(Rectangle())
    }
}

private struct ThumbShape: Shape {
    let tipHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { p in
            let cornerRadius: CGFloat = 3
            let bodyBottom = rect.maxY - tipHeight
            p.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
            p.addArc(
                center: CGPoint(x: rect.minX + cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
            p.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
            p.addArc(
                center: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY + cornerRadius),
                radius: cornerRadius,
                startAngle: .degrees(270),
                endAngle: .degrees(0),
                clockwise: false
            )
            p.addLine(to: CGPoint(x: rect.maxX, y: bodyBottom))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: bodyBottom))
            p.closeSubpath()
        }
    }
}
