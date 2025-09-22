import Foundation
import SwiftUI

@MainActor
final class CalendarViewModel: ObservableObject {
    @Published var currentDate = Date()
    @Published var calendarMonth: CalendarMonth
    @Published var selectedDay: CalendarDay?
    @Published var dayStats: [Date: DayPracticeStats] = [:]

    private var practiceRecordsStore: PracticeRecordsStore?
    private let calendar = Calendar.current

    init() {
        self.calendarMonth = CalendarViewModel.createEmptyMonth(for: Date())
        updateCalendar()
    }

    func bindPracticeRecordsStore(_ store: PracticeRecordsStore) {
        self.practiceRecordsStore = store
        updateCalendar()
    }

    func selectDay(_ day: CalendarDay) {
        selectedDay = day
    }

    func navigateToToday() {
        currentDate = Date()
        updateCalendar()
    }

    func navigateToPreviousMonth() {
        currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
        updateCalendar()
    }

    func navigateToNextMonth() {
        currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        updateCalendar()
    }

    private func updateCalendar() {
        calendarMonth = buildCalendarMonth(for: currentDate)
        buildDayStats()
    }

    private func buildCalendarMonth(for date: Date) -> CalendarMonth {
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)

        guard let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let monthRange = calendar.range(of: .day, in: .month, for: monthStart) else {
            return Self.createEmptyMonth(for: date)
        }

        let monthEnd = calendar.date(byAdding: .day, value: monthRange.count - 1, to: monthStart)!
        let startWeekday = calendar.component(.weekday, from: monthStart)
        let daysFromPrevMonth = (startWeekday - calendar.firstWeekday + 7) % 7

        var days: [CalendarDay] = []

        if daysFromPrevMonth > 0 {
            let prevMonth = calendar.date(byAdding: .month, value: -1, to: monthStart)!
            let prevMonthRange = calendar.range(of: .day, in: .month, for: prevMonth)!
            let prevMonthEnd = prevMonthRange.count

            for i in (prevMonthEnd - daysFromPrevMonth + 1)...prevMonthEnd {
                if let dayDate = calendar.date(from: DateComponents(
                    year: calendar.component(.year, from: prevMonth),
                    month: calendar.component(.month, from: prevMonth),
                    day: i
                )) {
                    days.append(createCalendarDay(for: dayDate, isCurrentMonth: false))
                }
            }
        }

        for day in 1...monthRange.count {
            if let dayDate = calendar.date(from: DateComponents(year: year, month: month, day: day)) {
                days.append(createCalendarDay(for: dayDate, isCurrentMonth: true))
            }
        }

        let totalCells = 42
        let remainingCells = totalCells - days.count
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart)!

        for day in 1...remainingCells {
            if let dayDate = calendar.date(from: DateComponents(
                year: calendar.component(.year, from: nextMonth),
                month: calendar.component(.month, from: nextMonth),
                day: day
            )) {
                days.append(createCalendarDay(for: dayDate, isCurrentMonth: false))
            }
        }

        return CalendarMonth(year: year, month: month, days: days)
    }

    private func createCalendarDay(for date: Date, isCurrentMonth: Bool) -> CalendarDay {
        let dayStart = calendar.startOfDay(for: date)
        let records = getRecordsForDay(dayStart)
        let practiceCount = records.count
        let averageScore = practiceCount > 0 ? records.map(\.score).reduce(0, +) / practiceCount : nil
        let errorCount = records.map(\.errors.count).reduce(0, +)

        return CalendarDay(
            date: dayStart,
            isCurrentMonth: isCurrentMonth,
            isToday: calendar.isDateInToday(date),
            practiceCount: practiceCount,
            averageScore: averageScore != nil ? Double(averageScore!) : nil,
            errorCount: errorCount
        )
    }

    private func buildDayStats() {
        guard let store = practiceRecordsStore else { return }

        var recordsByDay: [Date: [PracticeRecord]] = [:]
        for record in store.records {
            let dayStart = calendar.startOfDay(for: record.createdAt)
            recordsByDay[dayStart, default: []].append(record)
        }

        var stats: [Date: DayPracticeStats] = [:]
        for (dayStart, records) in recordsByDay {
            stats[dayStart] = DayPracticeStats(
                date: dayStart,
                records: records,
                streakDays: calculateStreakDays(endingAt: dayStart, recordsByDay: recordsByDay)
            )
        }

        dayStats = stats
    }

    private func getRecordsForDay(_ dayStart: Date) -> [PracticeRecord] {
        guard let store = practiceRecordsStore else { return [] }
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        return store.records.filter { record in
            record.createdAt >= dayStart && record.createdAt < dayEnd
        }
    }

    private func calculateStreakDays(endingAt dayStart: Date, recordsByDay: [Date: [PracticeRecord]]) -> Int {
        var streak = 0
        var currentDay = dayStart

        while recordsByDay[currentDay] != nil {
            streak += 1
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDay) else { break }
            currentDay = previousDay
        }

        return streak
    }

    private static func createEmptyMonth(for date: Date) -> CalendarMonth {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: date)
        let month = calendar.component(.month, from: date)
        return CalendarMonth(year: year, month: month, days: [])
    }
}
