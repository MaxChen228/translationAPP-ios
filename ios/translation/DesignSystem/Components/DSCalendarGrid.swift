import SwiftUI

struct DSCalendarGrid: View {
    let month: CalendarMonth
    let selectedDay: CalendarDay?
    let onDaySelected: (CalendarDay) -> Void

    private let weekdaySymbols = Calendar.current.shortWeekdaySymbols
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            weekdayHeader
            monthGrid
        }
    }

    private var weekdayHeader: some View {
        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .dsType(DS.Font.caption)
                    .foregroundStyle(DS.Palette.subdued)
                    .frame(height: DS.Spacing.lg)
            }
        }
    }

    private var monthGrid: some View {
        LazyVGrid(columns: columns, spacing: DS.Spacing.xs) {
            ForEach(month.days.indices, id: \.self) { index in
                let day = month.days[index]
                let isSelected = selectedDay?.date == day.date

                DSCalendarCell(
                    day: day,
                    isSelected: isSelected,
                    onTap: { onDaySelected(day) }
                )
            }
        }
    }
}