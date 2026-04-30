import SwiftUI

struct UsageToolCardView: View {
    let snapshot: UsageSnapshot
    let showWeeklyUsage: Bool
    let warningThreshold: Int
    let criticalThreshold: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label {
                Text(snapshot.tool.displayName)
            } icon: {
                Image(snapshot.tool.assetImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
            }
            .font(.headline)

            UsageMeterView(
                title: "usage.fiveHourRemaining",
                percent: snapshot.fiveHourRemainingPercent,
                resetAt: snapshot.fiveHourResetAt,
                level: level(for: snapshot.fiveHourRemainingPercent)
            )

            if showWeeklyUsage {
                UsageMeterView(
                    title: "usage.weeklyRemaining",
                    percent: snapshot.weeklyRemainingPercent,
                    resetAt: snapshot.weeklyResetAt,
                    level: level(for: snapshot.weeklyRemainingPercent)
                )
            }

            if let message = snapshot.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8))
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
    let title: LocalizedStringKey
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
                .progressViewStyle(.linear)
                .tint(tint)
                .accentColor(tint)

            ResetScheduleText(resetAt: resetAt)
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

private struct ResetScheduleText: View {
    let resetAt: Date?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { context in
            content(now: context.date)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if let resetAt {
            let seconds = resetAt.timeIntervalSince(now)
            if seconds <= 0 {
                Text("formatter.resetPassed")
            } else if seconds <= 2 * 24 * 60 * 60 {
                relativeResetText(resetAt, showsDetail: false)
            } else {
                relativeResetText(resetAt, showsDetail: true)
            }
        } else {
            Text("formatter.resetUnavailable")
        }
    }

    @ViewBuilder
    private func relativeResetText(_ resetAt: Date, showsDetail: Bool) -> some View {
        HStack(spacing: 0) {
            if !UsageFormatters.resetRelativePrefixText.isEmpty {
                Text(verbatim: UsageFormatters.resetRelativePrefixText)
            }

            Text(resetAt, style: .relative)

            if !UsageFormatters.resetRelativeSuffixText.isEmpty {
                Text(verbatim: UsageFormatters.resetRelativeSuffixText)
            }

            if showsDetail {
                Text(verbatim: " (\(UsageFormatters.resetDetailText(resetAt)))")
            }
        }
    }
}
