import Testing
import Foundation
@testable import translation

@Suite("CalendarViewModel")
struct CalendarViewModelTests {
    private func makeRecord(
        createdAt: Date,
        duration: TimeInterval = 90,
        score: Int,
        errorCount: Int
    ) -> PracticeRecord {
        let errors = (0..<errorCount).map { _ in
            ErrorItem(
                id: UUID(),
                span: "",
                type: .lexical,
                explainZh: "錯誤",
                suggestion: nil,
                hints: nil
            )
        }
        return PracticeRecord(
            createdAt: createdAt,
            completedAt: createdAt.addingTimeInterval(duration),
            chineseText: "題目",
            englishInput: "input",
            correctedText: "corrected",
            score: score,
            errors: errors
        )
    }

    @MainActor
    private func makeMemoryStore() -> PracticeRecordsStore {
        PracticeRecordsStore(repository: PracticeRecordsRepository(provider: MemoryPersistenceProvider()))
    }

    @MainActor
    @Test("綁定練習紀錄後更新月曆資料")
    func bindsPracticeRecordsIntoCalendar() throws {
        let store = makeMemoryStore()

        let calendar = Calendar(identifier: .gregorian)
        let target = calendar.date(from: DateComponents(year: 2024, month: 11, day: 15, hour: 8))!
        store.add(makeRecord(createdAt: target, score: 90, errorCount: 2))
        store.add(makeRecord(createdAt: target.addingTimeInterval(2 * 3600), score: 70, errorCount: 1))

        let viewModel = CalendarViewModel()
        viewModel.bindPracticeRecordsStore(store)

        #expect(viewModel.calendarMonth.days.count == 42)

        let targetDay = viewModel.calendarMonth.days.first { day in
            Calendar.current.isDate(day.date, inSameDayAs: target)
        }
        #expect(targetDay?.practiceCount == 2)
        #expect(targetDay?.averageScore == 80)
        #expect(targetDay?.errorCount == 3)
        #expect(targetDay?.isCurrentMonth == true)
    }

    @MainActor
    @Test("連續練習天數計算")
    func streakCalculation() throws {
        let store = makeMemoryStore()

        let calendar = Calendar(identifier: .gregorian)
        let day1 = calendar.date(from: DateComponents(year: 2024, month: 11, day: 10, hour: 9))!
        let day2 = calendar.date(from: DateComponents(year: 2024, month: 11, day: 11, hour: 9))!
        let day3 = calendar.date(from: DateComponents(year: 2024, month: 11, day: 12, hour: 9))!

        store.add(makeRecord(createdAt: day1, score: 75, errorCount: 1))
        store.add(makeRecord(createdAt: day2, score: 80, errorCount: 1))
        store.add(makeRecord(createdAt: day3, score: 85, errorCount: 1))

        let viewModel = CalendarViewModel()
        viewModel.bindPracticeRecordsStore(store)

        let startOfDay3 = Calendar.current.startOfDay(for: day3)
        let stats = viewModel.dayStats[startOfDay3]
        #expect(stats?.streakDays == 3)
        #expect(stats?.count == 1)
    }

    @MainActor
    @Test("月份導航切換前後月份資料")
    func monthNavigationUpdatesCalendar() throws {
        let viewModel = CalendarViewModel()
        let calendar = Calendar.current

        let baseComponents = DateComponents(year: viewModel.calendarMonth.year, month: viewModel.calendarMonth.month, day: 10, hour: 9)
        let baseDate = calendar.date(from: baseComponents) ?? Date()
        let previousDate = calendar.date(byAdding: .month, value: -1, to: baseDate) ?? baseDate
        let nextDate = calendar.date(byAdding: .month, value: 1, to: baseDate) ?? baseDate

        let store = makeMemoryStore()
        store.add(makeRecord(createdAt: baseDate, score: 90, errorCount: 1))
        store.add(makeRecord(createdAt: previousDate, score: 80, errorCount: 2))
        store.add(makeRecord(createdAt: nextDate, score: 70, errorCount: 3))

        viewModel.bindPracticeRecordsStore(store)

        let initialMonth = viewModel.calendarMonth

        viewModel.navigateToNextMonth()
        let expectedNext = calendar.date(byAdding: .month, value: 1, to: calendar.date(from: DateComponents(year: initialMonth.year, month: initialMonth.month, day: 10))!)!
        #expect(viewModel.calendarMonth.year == calendar.component(.year, from: expectedNext))
        #expect(viewModel.calendarMonth.month == calendar.component(.month, from: expectedNext))

        let nextDayDate = calendar.startOfDay(for: nextDate)
        let nextDay = viewModel.calendarMonth.days.first { calendar.isDate($0.date, inSameDayAs: nextDayDate) }
        #expect(nextDay?.practiceCount == 1)
        #expect(nextDay?.errorCount == 3)
        #expect(nextDay?.isCurrentMonth == true)

        viewModel.navigateToPreviousMonth()
        viewModel.navigateToPreviousMonth()

        let expectedPrevious = calendar.date(byAdding: .month, value: -1, to: calendar.date(from: DateComponents(year: initialMonth.year, month: initialMonth.month, day: 10))!)!
        #expect(viewModel.calendarMonth.year == calendar.component(.year, from: expectedPrevious))
        #expect(viewModel.calendarMonth.month == calendar.component(.month, from: expectedPrevious))

        let previousDayDate = calendar.startOfDay(for: previousDate)
        let previousDay = viewModel.calendarMonth.days.first { calendar.isDate($0.date, inSameDayAs: previousDayDate) }
        #expect(previousDay?.practiceCount == 1)
        #expect(previousDay?.errorCount == 2)
        #expect(previousDay?.isCurrentMonth == true)
    }

    @MainActor
    @Test("導航回今日會還原當月資料")
    func navigateToTodayRestoresCurrentMonth() throws {
        let viewModel = CalendarViewModel()
        let calendar = Calendar.current

        let baseComponents = DateComponents(year: viewModel.calendarMonth.year, month: viewModel.calendarMonth.month, day: 12, hour: 9)
        let baseDate = calendar.date(from: baseComponents) ?? Date()
        let store = makeMemoryStore()
        store.add(makeRecord(createdAt: baseDate, score: 95, errorCount: 0))

        viewModel.bindPracticeRecordsStore(store)
        let initialMonth = viewModel.calendarMonth

        viewModel.navigateToNextMonth()
        viewModel.navigateToPreviousMonth()
        viewModel.navigateToToday()

        #expect(viewModel.calendarMonth.year == initialMonth.year)
        #expect(viewModel.calendarMonth.month == initialMonth.month)

        let targetDay = calendar.startOfDay(for: baseDate)
        let todayEntry = viewModel.calendarMonth.days.first { calendar.isDate($0.date, inSameDayAs: targetDay) }
        #expect(todayEntry?.practiceCount == 1)
        #expect(todayEntry?.isCurrentMonth == true)
    }
}
