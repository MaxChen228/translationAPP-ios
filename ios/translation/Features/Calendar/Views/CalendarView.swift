import SwiftUI

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @EnvironmentObject private var practiceRecordsStore: PracticeRecordsStore

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xl) {
                    calendarCard

                    if let selectedDay = viewModel.selectedDay, selectedDay.hasActivity,
                       let stats = viewModel.dayStats[selectedDay.date] {
                        DSCard {
                            DayDetailView(stats: stats)
                        }
                        .transition(DSTransition.cardExpand)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.vertical, DS.Spacing.lg)
            }
            .navigationTitle("練習日曆")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
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

    private var calendarCard: some View {
        DSCard {
            VStack(spacing: DS.Spacing.lg) {
                calendarHeader

                DSCalendarGrid(
                    month: viewModel.calendarMonth,
                    selectedDay: viewModel.selectedDay,
                    onDaySelected: viewModel.selectDay
                )
            }
        }
    }

    private var calendarHeader: some View {
        HStack(spacing: DS.Spacing.md) {
            DSQuickActionIconButton(
                systemName: "chevron.left",
                labelKey: "上個月",
                action: viewModel.navigateToPreviousMonth,
                style: .outline
            )

            Spacer(minLength: DS.Spacing.md)

            Text(viewModel.calendarMonth.monthYear)
                .dsType(DS.Font.title)
                .fontWeight(.semibold)

            Spacer(minLength: DS.Spacing.md)

            DSQuickActionIconButton(
                systemName: "chevron.right",
                labelKey: "下個月",
                action: viewModel.navigateToNextMonth,
                style: .outline
            )
        }
    }
}
