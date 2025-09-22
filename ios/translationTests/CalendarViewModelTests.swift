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
}
