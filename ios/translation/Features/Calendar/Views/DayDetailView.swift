import SwiftUI

struct DayDetailView: View {
    let stats: DayPracticeStats

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            headerSection

            DSSeparator(color: DS.Palette.border.opacity(DS.Opacity.hairline))

            statsGrid

            if stats.count > 1 {
                practiceTimeInfo
            }
        }
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: DS.Spacing.md) {
            DSCardTitle(
                icon: "calendar",
                titleText: formattedDate,
                showChevron: false
            )

            Spacer()

            scoreIndicator
        }
    }

    private var scoreIndicator: some View {
        HStack(spacing: DS.Spacing.xs2) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.caption)
                .foregroundStyle(scoreColor)

            Text(averageScoreText)
                .dsType(DS.Font.labelMd)
                .fontWeight(.semibold)
                .foregroundStyle(scoreColor)
        }
        .padding(.horizontal, DS.Spacing.sm)
        .padding(.vertical, DS.Spacing.xs)
        .background(
            Capsule()
                .fill(scoreColor.opacity(DS.Opacity.fill))
        )
        .overlay(
            Capsule()
                .stroke(scoreColor.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.hairline)
        )
    }

    private var scoreColor: Color {
        DS.Palette.scoreColor(for: stats.averageScore)
    }

    private var statsGrid: some View {
        HStack(spacing: DS.Spacing.xl) {
            DSStatItem(
                icon: "doc.text",
                label: "練習題數",
                value: "\(stats.count)"
            )

            DSStatItem(
                icon: "exclamationmark.triangle",
                label: "錯誤總數",
                value: "\(stats.totalErrors)"
            )

            DSStatItem(
                icon: "star.fill",
                label: "最高分",
                value: "\(stats.bestScore)"
            )
        }
    }

    private var practiceTimeInfo: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "clock")
                .dsType(DS.Font.caption)
                .foregroundStyle(DS.Palette.subdued)

            Text("總練習時間：\(formattedPracticeTime)")
                .dsType(DS.Font.caption)
                .foregroundStyle(DS.Palette.subdued)
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter.string(from: stats.date)
    }

    private var averageScoreText: String {
        String(format: "%.1f", stats.averageScore)
    }

    private var formattedPracticeTime: String {
        let minutes = Int(stats.practiceTime / 60)
        if minutes < 60 {
            return "\(minutes) 分鐘"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "\(hours) 小時 \(remainingMinutes) 分鐘"
        }
    }
}
