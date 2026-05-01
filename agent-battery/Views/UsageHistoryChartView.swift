import SwiftUI

struct UsageHistoryChartSeries: Identifiable {
    let id: UsageTool
    let title: String
    let color: Color
    let points: [UsageHistoryPoint]
    let resetAt: Date?

    var resetPoint: UsageHistoryPoint? {
        guard let latest = points.last,
              let resetAt,
              resetAt > latest.date else {
            return nil
        }

        return UsageHistoryPoint(date: resetAt, percent: 100)
    }
}

struct UsageHistoryPoint: Identifiable {
    var id: String { "\(date.timeIntervalSince1970)-\(percent)" }

    let date: Date
    let percent: Double
}

struct UsageHistoryChartView: View {
    let title: LocalizedStringKey
    let series: [UsageHistoryChartSeries]

    private let chartHeight: CGFloat = 86

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                chartLegend
            }

            VStack(spacing: 4) {
                ZStack {
                    UsageHistoryChartGrid()

                    if let dateRange, hasChartData {
                        UsageHistoryPlotView(
                            series: series,
                            dateRange: dateRange,
                            valueRange: valueRange
                        )
                    } else {
                        Text("usage.historyNoData")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(height: chartHeight)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))

                if let dateRange, hasChartData {
                    UsageHistoryTimeAxisView(
                        dateRange: dateRange,
                        latestDate: latestHistoryDate,
                        showsUpperBound: shouldShowAxisUpperBound(for: dateRange)
                    )
                }
            }
        }
    }

    private var chartLegend: some View {
        HStack(spacing: 8) {
            ForEach(series) { item in
                UsageHistoryLegendItem(title: item.title, color: item.color)
            }
        }
    }

    private var hasChartData: Bool {
        !series.isEmpty
    }

    private var dateRange: ClosedRange<Date>? {
        let dates = series.flatMap { item -> [Date] in
            var dates = item.points.map(\.date)
            if let resetDate = item.resetPoint?.date {
                dates.append(resetDate)
            }
            return dates
        }
        guard let lower = dates.min(), var upper = dates.max() else {
            return nil
        }

        if upper <= lower {
            upper = lower.addingTimeInterval(60)
        }

        return lower...upper
    }

    private var latestHistoryDate: Date? {
        series
            .compactMap { $0.points.last?.date }
            .max()
    }

    private var valueRange: ClosedRange<Double> {
        let values = series.flatMap { item -> [Double] in
            var values = item.points.map(\.percent)
            if let resetPercent = item.resetPoint?.percent {
                values.append(resetPercent)
            }
            return values
        }

        guard let minimum = values.min() else {
            return 0...100
        }

        let lowerBound = max(
            0,
            UsageMath.clampPercent(minimum) - UsageHistoryChartLayout.valueLowerPadding
        )
        return lowerBound...100
    }

    private func shouldShowAxisUpperBound(for dateRange: ClosedRange<Date>) -> Bool {
        guard let latestHistoryDate else {
            return true
        }

        return dateRange.upperBound <= latestHistoryDate
    }
}

private struct UsageHistoryLegendItem: View {
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)

            Text(verbatim: title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .fixedSize()
    }
}

private struct UsageHistoryChartGrid: View {
    private let fractions = [0.25, 0.5, 0.75]

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                for fraction in fractions {
                    let y = geometry.size.height * fraction
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }

                path.move(to: CGPoint(x: 0, y: geometry.size.height - 1))
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height - 1))
            }
            .stroke(Color.secondary.opacity(0.14), lineWidth: 1)
        }
        .allowsHitTesting(false)
    }
}

private struct UsageHistoryPlotView: View {
    let series: [UsageHistoryChartSeries]
    let dateRange: ClosedRange<Date>
    let valueRange: ClosedRange<Double>

    @State private var hoveredResetIDs: Set<UsageTool> = []

    private let markerSize: CGFloat = 6
    private let resetHoverRadius: CGFloat = 4

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(series) { item in
                    if item.points.count > 1 {
                        historyPath(for: item.points, in: geometry.size)
                            .stroke(
                                item.color,
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                            )
                    }

                    if let latest = item.points.last,
                       let resetPoint = item.resetPoint {
                        connectionPath(from: latest, to: resetPoint, in: geometry.size)
                            .stroke(
                                item.color.opacity(0.75),
                                style: StrokeStyle(
                                    lineWidth: 1.5,
                                    lineCap: .round,
                                    lineJoin: .round,
                                    dash: [4, 4]
                                )
                            )
                    }
                }
                .allowsHitTesting(false)

                ForEach(Array(series.enumerated()), id: \.element.id) { index, item in
                    if let latest = item.points.last {
                        UsageHistoryMarker(color: item.color, filled: true, highlighted: false)
                            .frame(width: markerSize, height: markerSize)
                            .position(position(for: latest, in: geometry.size))
                            .allowsHitTesting(false)

                        Text(UsageFormatters.percentText(latest.percent))
                            .font(.caption2.monospacedDigit())
                            .fontWeight(.semibold)
                            .foregroundStyle(item.color)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.thinMaterial, in: Capsule())
                            .position(labelPosition(
                                for: latest,
                                in: geometry.size,
                                offset: latestLabelOffset(for: index)
                            ))
                            .allowsHitTesting(false)
                    }

                    if let resetPoint = item.resetPoint {
                        let highlighted = hoveredResetIDs.contains(item.id)

                        if highlighted {
                            verticalGuide(for: resetPoint, in: geometry.size)
                                .stroke(
                                    item.color.opacity(0.55),
                                    style: StrokeStyle(lineWidth: 1, dash: [3, 4])
                                )
                                .allowsHitTesting(false)
                        }

                        UsageHistoryMarker(
                            color: item.color,
                            filled: false,
                            highlighted: highlighted
                        )
                            .frame(width: markerSize, height: markerSize)
                            .position(position(for: resetPoint, in: geometry.size))
                            .allowsHitTesting(false)

                        if highlighted {
                            ResetCountdownLabel(resetAt: resetPoint.date, color: item.color)
                                .position(labelPosition(
                                    for: resetPoint,
                                    in: geometry.size,
                                    offset: resetLabelOffset(for: index)
                                ))
                                .allowsHitTesting(false)
                        }
                    }
                }

                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case let .active(location):
                            hoveredResetIDs = resetIDs(near: location, in: geometry.size)
                        case .ended:
                            hoveredResetIDs = []
                        }
                    }
            }
        }
    }

    private func historyPath(for points: [UsageHistoryPoint], in size: CGSize) -> Path {
        Path { path in
            for (index, point) in points.enumerated() {
                let location = position(for: point, in: size)
                if index == 0 {
                    path.move(to: location)
                } else {
                    path.addLine(to: location)
                }
            }
        }
    }

    private func resetIDs(near location: CGPoint, in size: CGSize) -> Set<UsageTool> {
        Set(series.compactMap { item in
            guard let resetPoint = item.resetPoint else {
                return nil
            }

            let markerPosition = position(for: resetPoint, in: size)
            let distance = hypot(location.x - markerPosition.x, location.y - markerPosition.y)
            return distance <= resetHoverRadius ? item.id : nil
        })
    }

    private func connectionPath(
        from latest: UsageHistoryPoint,
        to reset: UsageHistoryPoint,
        in size: CGSize
    ) -> Path {
        Path { path in
            path.move(to: position(for: latest, in: size))
            path.addLine(to: position(for: reset, in: size))
        }
    }

    private func verticalGuide(for point: UsageHistoryPoint, in size: CGSize) -> Path {
        let x = position(for: point, in: size).x

        return Path { path in
            path.move(to: CGPoint(x: x, y: UsageHistoryChartLayout.topInset))
            path.addLine(to: CGPoint(
                x: x,
                y: size.height - UsageHistoryChartLayout.bottomInset
            ))
        }
    }

    private func position(for point: UsageHistoryPoint, in size: CGSize) -> CGPoint {
        let span = dateRange.upperBound.timeIntervalSince(dateRange.lowerBound)
        let xFraction = span > 0
            ? point.date.timeIntervalSince(dateRange.lowerBound) / span
            : 0.5
        let valueSpan = valueRange.upperBound - valueRange.lowerBound
        let clampedPercent = min(max(point.percent, valueRange.lowerBound), valueRange.upperBound)
        let yFraction = valueSpan > 0
            ? 1 - (clampedPercent - valueRange.lowerBound) / valueSpan
            : 0.5

        return CGPoint(
            x: UsageHistoryChartLayout.leftInset + UsageHistoryChartLayout.width(in: size) * xFraction,
            y: UsageHistoryChartLayout.topInset + UsageHistoryChartLayout.height(in: size) * yFraction
        )
    }

    private func labelPosition(
        for point: UsageHistoryPoint,
        in size: CGSize,
        offset: CGSize
    ) -> CGPoint {
        let base = position(for: point, in: size)
        return CGPoint(
            x: min(max(base.x + offset.width, 24), size.width - 24),
            y: min(max(base.y + offset.height, 9), size.height - 9)
        )
    }

    private func latestLabelOffset(for index: Int) -> CGSize {
        index.isMultiple(of: 2)
            ? CGSize(width: 24, height: -12)
            : CGSize(width: 24, height: 13)
    }

    private func resetLabelOffset(for index: Int) -> CGSize {
        index.isMultiple(of: 2)
            ? CGSize(width: -24, height: 13)
            : CGSize(width: -24, height: -12)
    }
}

private struct UsageHistoryTimeAxisView: View {
    let dateRange: ClosedRange<Date>
    let latestDate: Date?
    let showsUpperBound: Bool

    var body: some View {
        HStack(spacing: 8) {
            Text(UsageHistoryAxisFormatter.axisText(dateRange.lowerBound))

            Spacer(minLength: 4)

            if let latestDate, shouldShowLatestLabel(latestDate) {
                Text(UsageHistoryAxisFormatter.axisText(latestDate))

                Spacer(minLength: 4)
            }

            if showsUpperBound {
                Text(UsageHistoryAxisFormatter.axisText(dateRange.upperBound))
            }
        }
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func shouldShowLatestLabel(_ latestDate: Date) -> Bool {
        let minimumGap: TimeInterval = 10 * 60
        let hasEnoughLowerGap = latestDate.timeIntervalSince(dateRange.lowerBound) > minimumGap
        guard showsUpperBound else {
            return hasEnoughLowerGap
        }

        return hasEnoughLowerGap
            && dateRange.upperBound.timeIntervalSince(latestDate) > minimumGap
    }
}

private struct UsageHistoryMarker: View {
    let color: Color
    let filled: Bool
    let highlighted: Bool

    var body: some View {
        Circle()
            .fill(fill)
            .overlay(
                Circle()
                    .stroke(color, lineWidth: strokeWidth)
            )
            .shadow(color: highlighted ? color.opacity(0.35) : .clear, radius: 4)
    }

    private var fill: Color {
        if filled {
            return color
        }

        return highlighted ? color.opacity(0.18) : Color.secondary.opacity(0.08)
    }

    private var strokeWidth: CGFloat {
        if filled {
            return 0
        }

        return highlighted ? 2.2 : 1.5
    }
}

private struct ResetCountdownLabel: View {
    let resetAt: Date
    let color: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            Text(verbatim: UsageFormatters.resetCountdownText(until: resetAt, now: context.date))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(color)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(.thinMaterial, in: Capsule())
        }
    }
}

private enum UsageHistoryChartLayout {
    static let leftInset: CGFloat = 8
    static let rightInset: CGFloat = 42
    static let topInset: CGFloat = 14
    static let bottomInset: CGFloat = 10
    static let valueLowerPadding: Double = 5

    static func width(in size: CGSize) -> CGFloat {
        max(size.width - leftInset - rightInset, 1)
    }

    static func height(in size: CGSize) -> CGFloat {
        max(size.height - topInset - bottomInset, 1)
    }
}

private enum UsageHistoryAxisFormatter {
    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("HH:mm")
        return formatter
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("M/d HH:mm")
        return formatter
    }()

    static func axisText(_ date: Date) -> String {
        Calendar.current.isDateInToday(date)
            ? timeFormatter.string(from: date)
            : dateTimeFormatter.string(from: date)
    }
}
