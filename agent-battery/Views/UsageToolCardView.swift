import SwiftUI

struct UsageToolCardView: View {
    let snapshot: UsageSnapshot
    let showWeeklyUsage: Bool
    let warningThreshold: Int
    let criticalThreshold: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(snapshot.tool.displayName, systemImage: snapshot.tool.systemImage)
                    .font(.headline)

                Spacer()

                Text(snapshot.status.title)
                    .font(.caption)
                    .foregroundStyle(statusColor)
            }

            UsageMeterView(
                title: "5h Remaining",
                percent: snapshot.fiveHourRemainingPercent,
                resetAt: snapshot.fiveHourResetAt,
                level: level(for: snapshot.fiveHourRemainingPercent)
            )

            if showWeeklyUsage {
                UsageMeterView(
                    title: "Weekly Remaining",
                    percent: snapshot.weeklyRemainingPercent,
                    resetAt: snapshot.weeklyResetAt,
                    level: level(for: snapshot.weeklyRemainingPercent)
                )
            }

            HStack(alignment: .firstTextBaseline) {
                Text(UsageFormatters.updatedText(snapshot.updatedAt, status: snapshot.status))

                if let message = snapshot.message {
                    Text(message)
                        .lineLimit(2)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusColor: Color {
        switch snapshot.status {
        case .available:
            .secondary
        case .unavailable:
            .secondary
        case .stale:
            .orange
        case .error:
            .red
        }
    }

    private func level(for percent: Double?) -> UsageLevel {
        UsageMath.level(
            for: percent,
            warningThreshold: warningThreshold,
            criticalThreshold: criticalThreshold
        )
    }
}

private struct UsageMeterView: View {
    let title: String
    let percent: Double?
    let resetAt: Date?
    let level: UsageLevel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(UsageFormatters.percentText(percent))
                    .font(.system(.body, design: .rounded))
                    .fontWeight(.semibold)
            }

            ProgressView(value: progress)
                .tint(tint)

            Text(UsageFormatters.resetText(resetAt))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var progress: Double {
        guard let percent else {
            return 0
        }
        return UsageMath.clampPercent(percent) / 100
    }

    private var tint: Color {
        switch level {
        case .normal:
            .green
        case .warning:
            .orange
        case .critical:
            .red
        case .unavailable:
            .secondary
        }
    }
}
