import Testing
import Foundation
@testable import translation

@Suite("PracticeRecordsStore")
struct PracticeRecordsStoreTests {
    private let defaultsKey = "practice.records"

    private func makeRecord(
        id: UUID = UUID(),
        createdAt: Date,
        duration: TimeInterval = 60,
        score: Int,
        errorCount: Int,
        bankBookName: String? = nil,
        tag: String? = nil
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
            id: id,
            createdAt: createdAt,
            completedAt: createdAt.addingTimeInterval(duration),
            bankItemId: nil,
            bankBookName: bankBookName,
            practiceTag: tag,
            chineseText: "中文題目",
            englishInput: "English input",
            hints: [],
            teacherSuggestion: nil,
            correctedText: "Corrected text",
            score: score,
            errors: errors,
            attemptCount: 1
        )
    }

    private func withCleanDefaults<T>(_ body: () throws -> T) rethrows -> T {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: defaultsKey)
        defaults.removeObject(forKey: defaultsKey)
        defer {
            if let data = previous as? Data {
                defaults.set(data, forKey: defaultsKey)
            } else {
                defaults.removeObject(forKey: defaultsKey)
            }
        }
        return try body()
    }

    @MainActor
    @Test("add/remove 基本操作")
    func addAndRemoveRecords() throws {
        try withCleanDefaults {
            let store = PracticeRecordsStore()
            store.clearAll()

            let today = Date()
            let record = makeRecord(createdAt: today, score: 80, errorCount: 2)
            store.add(record)

            #expect(store.records.count == 1)
            #expect(store.getRecord(by: record.id) == record)

            store.remove(record.id)
            #expect(store.records.isEmpty)
        }
    }

    @MainActor
    @Test("統計資料計算")
    func statisticsCalculation() throws {
        try withCleanDefaults {
            let store = PracticeRecordsStore()
            store.clearAll()

            let base = Date()
            store.add(makeRecord(createdAt: base, score: 90, errorCount: 1))
            store.add(makeRecord(createdAt: base.addingTimeInterval(120), score: 60, errorCount: 3))

            let stats = store.getStatistics()
            #expect(stats.totalRecords == 2)
            #expect(stats.averageScore == 75)
            #expect(stats.totalErrors == 4)
        }
    }

    @MainActor
    @Test("依日期分組")
    func groupingByDate() throws {
        try withCleanDefaults {
            let store = PracticeRecordsStore()
            store.clearAll()

            let calendar = Calendar(identifier: .gregorian)
            let day1 = calendar.date(from: DateComponents(year: 2024, month: 12, day: 1, hour: 9, minute: 30))!
            let day2 = calendar.date(from: DateComponents(year: 2024, month: 12, day: 2, hour: 9, minute: 30))!

            store.add(makeRecord(createdAt: day1, score: 85, errorCount: 1, bankBookName: "Book A"))
            store.add(makeRecord(createdAt: day1.addingTimeInterval(3600), score: 70, errorCount: 2, bankBookName: "Book A"))
            store.add(makeRecord(createdAt: day2, score: 95, errorCount: 0, bankBookName: "Book B"))

            let grouped = store.getRecordsGroupedByDate()
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none

            let key1 = formatter.string(from: day1)
            let key2 = formatter.string(from: day2)

            #expect(grouped.count == 2)
            #expect(grouped[key1]?.count == 2)
            #expect(grouped[key2]?.count == 1)
            #expect(grouped.values.map(\.count).reduce(0, +) == 3)
        }
    }

    @MainActor
    @Test("持久化與重新載入")
    func persistenceRoundtrip() throws {
        try withCleanDefaults {
            let store = PracticeRecordsStore()
            store.clearAll()

            let created = Date(timeIntervalSince1970: 1_700_000_000)
            let record = makeRecord(createdAt: created, score: 88, errorCount: 2, bankBookName: "Book C", tag: "tag")
            store.add(record)

            let reloaded = PracticeRecordsStore()
            #expect(reloaded.records.count == 1)
            #expect(reloaded.records.first?.score == 88)
            #expect(reloaded.records.first?.bankBookName == "Book C")
            #expect(reloaded.records.first?.practiceTag == "tag")
        }
    }
}
