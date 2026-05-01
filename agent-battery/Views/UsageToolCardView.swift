import SwiftUI

struct UsageToolCardView: View {
    let tools: [UsageTool]
    let snapshots: [UsageTool: UsageSnapshot]
    let histories: [UsageTool: [UsageHistoryEntry]]
    let showWeeklyUsage: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            UsageMetricCardView(
                title: "usage.fiveHourRemaining",
                series: series(
                    percent: { $0.fiveHourRemainingPercent },
                    resetAt: { $0.fiveHourResetAt }
                )
            )

            if showWeeklyUsage {
                UsageMetricCardView(
                    title: "usage.weeklyRemaining",
                    series: series(
                        percent: { $0.weeklyRemainingPercent },
                        resetAt: { $0.weeklyResetAt }
                    )
                )
            }

            ForEach(statusMessages, id: \.self) { message in
                Text(verbatim: message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
    }

    private var statusMessages: [String] {
        tools.compactMap { tool in
            guard let message = snapshots[tool]?.message, !message.isEmpty else {
                return nil
            }

            return "\(tool.shortName): \(message)"
        }
    }

    private func series(
        percent: (UsageHistoryEntry) -> Double?,
        resetAt: (UsageHistoryEntry) -> Date?
    ) -> [UsageHistoryChartSeries] {
        tools.compactMap { tool in
            let entries = (histories[tool] ?? []).sorted { $0.recordedAt < $1.recordedAt }
            let points = entries.compactMap { entry -> UsageHistoryPoint? in
                guard let value = percent(entry) else {
                    return nil
                }

                return UsageHistoryPoint(
                    date: entry.recordedAt,
                    percent: UsageMath.clampPercent(value)
                )
            }

            guard !points.isEmpty else {
                return nil
            }

            let latestEntry = entries.last { percent($0) != nil }
            return UsageHistoryChartSeries(
                id: tool,
                title: tool.displayName,
                color: color(for: tool),
                points: points,
                resetAt: latestEntry.flatMap(resetAt)
            )
        }
    }

    private func color(for tool: UsageTool) -> Color {
        switch tool {
        case .claudeCode:
            Color(red: 0.85, green: 0.45, blue: 0.24)
        case .codex:
            .accentColor
        }
    }
}

private struct UsageMetricCardView: View {
    let title: LocalizedStringKey
    let series: [UsageHistoryChartSeries]

    var body: some View {
        UsageHistoryChartView(title: title, series: series)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }
}
