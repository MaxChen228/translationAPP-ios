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
                .dsType(DS.Font.title)
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