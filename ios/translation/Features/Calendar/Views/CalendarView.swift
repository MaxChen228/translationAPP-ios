import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @EnvironmentObject private var practiceRecordsStore: PracticeRecordsStore
    @State private var showDayDetail = false

    var body: some View {
        NavigationView {
            VStack(spacing: DS.Spacing.lg) {
                calendarHeader

                DSCard {
                    DSCalendarGrid(
                        month: viewModel.calendarMonth,
                        selectedDay: viewModel.selectedDay,
                        onDaySelected: viewModel.selectDay
                    )
                }

                if let selectedDay = viewModel.selectedDay, selectedDay.hasActivity {
                    dayDetailsCard
                        .transition(DSTransition.cardExpand)
                }

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .navigationTitle("練習日曆")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    DSQuickActionIconButton(
                        systemName: "calendar.badge.clock",
                        labelKey: "回到今天",
                        action: viewModel.navigateToToday,
                        style: .tinted
                    )
                }
            }
        }
        .onAppear {
            viewModel.bindPracticeRecordsStore(practiceRecordsStore)
        }
        .dsAnimation(DS.AnimationToken.bouncy, value: viewModel.selectedDay)
    }

    private var calendarHeader: some View {
        HStack {
            DSQuickActionIconButton(
                systemName: "chevron.left",
                labelKey: "上個月",
                action: viewModel.navigateToPreviousMonth,
                style: .outline
            )

            Spacer()

            Text(viewModel.calendarMonth.monthYear)
                .font(DS.Font.title)
                .fontWeight(.semibold)

            Spacer()

            DSQuickActionIconButton(
                systemName: "chevron.right",
                labelKey: "下個月",
                action: viewModel.navigateToNextMonth,
                style: .outline
            )
        }
    }

    private var dayDetailsCard: some View {
        DSCard {
            if let selectedDay = viewModel.selectedDay,
               let stats = viewModel.dayStats[selectedDay.date] {
                DayDetailView(stats: stats)
            }
        }
    }
}

private struct DayDetailView: View {
    let stats: DayPracticeStats

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack {
                Text(dateFormatter.string(from: stats.date))
                    .font(DS.Font.section)
                    .fontWeight(.semibold)

                Spacer()

                scoreIndicator
            }

            statsGrid

            if stats.count > 1 {
                practiceTimeInfo
            }
        }
    }

    private var scoreIndicator: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.caption)
                .foregroundStyle(scoreColor)

            Text("\(Int(stats.averageScore))")
                .font(DS.Font.labelMd)
                .fontWeight(.semibold)
                .foregroundStyle(scoreColor)
        }
        .padding(.horizontal, DS.Spacing.xs2)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(scoreColor.opacity(DS.Opacity.fill))
        )
    }

    private var scoreColor: Color {
        switch stats.averageScore {
        case 90...: return DS.Palette.success
        case 70..<90: return DS.Palette.warning
        case 50..<70: return DS.Palette.caution
        default: return DS.Palette.danger
        }
    }

    private var statsGrid: some View {
        HStack(spacing: DS.Spacing.lg) {
            StatItem(
                icon: "doc.text",
                label: "練習題數",
                value: "\(stats.count)"
            )

            StatItem(
                icon: "exclamationmark.triangle",
                label: "錯誤總數",
                value: "\(stats.totalErrors)"
            )

            StatItem(
                icon: "star.fill",
                label: "最高分",
                value: "\(stats.bestScore)"
            )
        }
    }

    private var practiceTimeInfo: some View {
        HStack {
            Image(systemName: "clock")
                .foregroundStyle(DS.Palette.subdued)
                .font(.caption)

            Text("總練習時間：\(formattedPracticeTime)")
                .font(DS.Font.caption)
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

private struct StatItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(DS.Palette.primary)

            Text(value)
                .font(DS.Font.labelMd)
                .fontWeight(.semibold)

            Text(label)
                .font(DS.Font.caption)
                .foregroundStyle(DS.Palette.subdued)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}