import Testing
import Foundation
@testable import translation

@MainActor
@Suite("PracticeRecordsStore")
struct PracticeRecordsStoreTests {
    private final class SpyRepository: PracticeRecordsRepositoryProtocol {
        enum SpyError: Error { case saveFailure }

        var stored: [PracticeRecord]
        var loadCallCount = 0
        var saveCallCount = 0
        var shouldThrowOnSave = false

        init(initial: [PracticeRecord] = []) {
            self.stored = initial
        }

        func loadRecords() throws -> [PracticeRecord] {
            loadCallCount &+= 1
            return stored
        }

        func saveRecords(_ records: [PracticeRecord]) throws {
            saveCallCount &+= 1
            if shouldThrowOnSave {
                throw SpyError.saveFailure
            }
            stored = records
        }
    }
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

    private func makeMemoryStore(initialRecords: [PracticeRecord] = []) -> PracticeRecordsStore {
        let repository = PracticeRecordsRepository(provider: MemoryPersistenceProvider())
        let store = PracticeRecordsStore(repository: repository)
        initialRecords.forEach { store.add($0) }
        return store
    }

    private func makeFileBackedRepository() throws -> (repository: PracticeRecordsRepository, directory: URL, cleanup: () -> Void) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("practiceRecords-test-\(UUID().uuidString)", isDirectory: true)
        let provider = try FilePersistenceProvider(directory: directory)
        let repository = PracticeRecordsRepository(provider: provider)
        let cleanup: () -> Void = {
            _ = try? FileManager.default.removeItem(at: directory)
        }
        return (repository, directory, cleanup)
    }

    @MainActor
    @Test("add/remove 基本操作")
    func addAndRemoveRecords() throws {
        let store = makeMemoryStore()

        let today = Date()
        let record = makeRecord(createdAt: today, score: 80, errorCount: 2)
        store.add(record)

        #expect(store.records.count == 1)
        #expect(store.getRecord(by: record.id) == record)

        store.remove(record.id)
        #expect(store.records.isEmpty)
    }

    @MainActor
    @Test("統計資料計算")
    func statisticsCalculation() throws {
        let store = makeMemoryStore()

        let base = Date()
        store.add(makeRecord(createdAt: base, score: 90, errorCount: 1))
        store.add(makeRecord(createdAt: base.addingTimeInterval(120), score: 60, errorCount: 3))

        let stats = store.getStatistics()
        #expect(stats.totalRecords == 2)
        #expect(stats.averageScore == 75)
        #expect(stats.totalErrors == 4)
    }

    @MainActor
    @Test("依日期分組")
    func groupingByDate() throws {
        let store = makeMemoryStore()

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

    @MainActor
    @Test("持久化與重新載入")
    func persistenceRoundtrip() throws {
        let (repository, directory, cleanup) = try makeFileBackedRepository()
        defer { cleanup() }

        let store = PracticeRecordsStore(repository: repository)
        store.clearAll()

        let created = Date(timeIntervalSince1970: 1_700_000_000)
        let record = makeRecord(createdAt: created, score: 88, errorCount: 2, bankBookName: "Book C", tag: "tag")
        store.add(record)

        let reloadedProvider = try FilePersistenceProvider(directory: directory)
        let reloadedRepository = PracticeRecordsRepository(provider: reloadedProvider)
        let reloadedStore = PracticeRecordsStore(repository: reloadedRepository)
        #expect(reloadedStore.records.count == 1)
        #expect(reloadedStore.records.first?.score == 88)
        #expect(reloadedStore.records.first?.bankBookName == "Book C")
        #expect(reloadedStore.records.first?.practiceTag == "tag")
    }

    @MainActor
    @Test("reload 從 repository 重新載入最新資料")
    func reloadRefreshesFromRepository() throws {
        let record = makeRecord(createdAt: Date(), score: 92, errorCount: 1, bankBookName: "Book R")
        let repository = SpyRepository(initial: [])
        let store = PracticeRecordsStore(repository: repository)

        #expect(store.records.isEmpty)

        repository.stored = [record]
        store.reload()

        #expect(repository.loadCallCount >= 1)
        #expect(store.records == [record])
    }

    @MainActor
    @Test("查詢特定書籍與分數的紀錄")
    func filteringHelpersReturnMatches() throws {
        let recordA = makeRecord(createdAt: Date(), score: 88, errorCount: 1, bankBookName: "Book A")
        let recordB = makeRecord(createdAt: Date().addingTimeInterval(100), score: 72, errorCount: 2, bankBookName: "Book B")
        let store = makeMemoryStore(initialRecords: [recordA, recordB])

        let bookARecords = store.getRecords(for: "Book A")
        let score72Records = store.getRecords(with: 72)

        #expect(bookARecords == [recordA])
        #expect(score72Records == [recordB])
    }

    @MainActor
    @Test("持久化失敗不應拋錯且保留記錄")
    func persistFailureKeepsInMemoryState() throws {
        let repository = SpyRepository(initial: [])
        repository.shouldThrowOnSave = true
        let store = PracticeRecordsStore(repository: repository)
        let record = makeRecord(createdAt: Date(), score: 77, errorCount: 2)

        store.add(record)

        #expect(store.records == [record])
        #expect(repository.stored.isEmpty)

        // 再次執行 remove 應該也不崩潰
        store.remove(record.id)
        #expect(repository.saveCallCount == 2)
        #expect(store.records.isEmpty)
    }
}
