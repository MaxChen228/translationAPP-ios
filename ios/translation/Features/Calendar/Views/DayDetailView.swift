import SwiftUI

struct DayDetailView: View {
    let stats: DayPracticeStats

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            headerSection
            statsGrid

            if stats.count > 1 {
                practiceTimeInfo
            }
        }
    }

    private var headerSection: some View {
        HStack {
            Text(dateFormatter.string(from: stats.date))
                .dsType(DS.Font.section)
                .fontWeight(.semibold)

            Spacer()

            scoreIndicator
        }
    }

    private var scoreIndicator: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .dsType(DS.Font.caption)
                .foregroundStyle(scoreColor)

            Text("\(Int(stats.averageScore))")
                .dsType(DS.Font.labelMd)
                .fontWeight(.semibold)
                .foregroundStyle(scoreColor)
        }
        .padding(.horizontal, DS.Spacing.xs2)
        .padding(.vertical, DS.Spacing.xs2)
        .background(
            Capsule()
                .fill(scoreColor.opacity(DS.Opacity.fill))
        )
    }

    private var scoreColor: Color {
        DS.Palette.scoreColor(for: stats.averageScore)
    }

    private var statsGrid: some View {
        HStack(spacing: DS.Spacing.lg) {
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