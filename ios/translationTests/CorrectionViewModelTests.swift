import Foundation
import Testing
import SwiftUI
@testable import translation

// MARK: - Test Doubles

@MainActor
private final class SpyWorkspaceStatePersistence: WorkspaceStatePersisting {
    private(set) var strings: [WorkspaceStateKey: String]
    private(set) var data: [WorkspaceStateKey: Data]
    private(set) var bools: [WorkspaceStateKey: Bool]

    private(set) var removedKeys: [WorkspaceStateKey] = []
    private(set) var removeAllInvocations: [[WorkspaceStateKey]] = []

    init(
        strings: [WorkspaceStateKey: String] = [:],
        data: [WorkspaceStateKey: Data] = [:],
        bools: [WorkspaceStateKey: Bool] = [:]
    ) {
        self.strings = strings
        self.data = data
        self.bools = bools
    }

    func readString(_ key: WorkspaceStateKey) -> String? { strings[key] }

    func writeString(_ value: String?, key: WorkspaceStateKey) {
        if let value {
            strings[key] = value
        } else {
            strings.removeValue(forKey: key)
        }
    }

    func readData(_ key: WorkspaceStateKey) -> Data? { data[key] }

    func writeData(_ value: Data?, key: WorkspaceStateKey) {
        if let value {
            data[key] = value
        } else {
            data.removeValue(forKey: key)
        }
    }

    func readBool(_ key: WorkspaceStateKey) -> Bool { bools[key] ?? false }

    func writeBool(_ value: Bool, key: WorkspaceStateKey) {
        bools[key] = value
    }

    func remove(_ key: WorkspaceStateKey) {
        strings.removeValue(forKey: key)
        data.removeValue(forKey: key)
        bools.removeValue(forKey: key)
        removedKeys.append(key)
    }

    func removeAll(_ keys: [WorkspaceStateKey]) {
        removeAllInvocations.append(keys)
        for key in keys { remove(key) }
    }
}

@MainActor
private final class UnusedCorrectionRunner: CorrectionRunning {
    private(set) var callCount = 0

    func runCorrection(
        zh: String,
        en: String,
        bankItemId: String?,
        deviceId: String?,
        hints: [BankHint]?,
        suggestion: String?
    ) async throws -> AICorrectionResult {
        callCount += 1
        fatalError("runCorrection should not be invoked in these tests")
    }
}

private final class TestPracticeRecordsRepository: PracticeRecordsRepositoryProtocol {
    var storedRecords: [PracticeRecord]
    private(set) var savedSnapshots: [[PracticeRecord]] = []

    init(initialRecords: [PracticeRecord] = []) {
        self.storedRecords = initialRecords
    }

    func loadRecords() throws -> [PracticeRecord] {
        storedRecords
    }

    func saveRecords(_ records: [PracticeRecord]) throws {
        savedSnapshots.append(records)
        storedRecords = records
    }
}

// MARK: - Fixtures

private extension CorrectionViewModelTests {
    var sampleErrorID: UUID { UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")! }

    var sampleError: ErrorItem {
        ErrorItem(
            id: sampleErrorID,
            span: "go",
            type: .lexical,
            explainZh: "使用過去式",
            suggestion: "went",
            hints: ErrorHints(before: "i ", after: " to", occurrence: nil)
        )
    }

    var sampleResponse: AIResponse {
        AIResponse(corrected: "I went to school.", score: 78, errors: [sampleError])
    }

    var sampleHint: BankHint {
        BankHint(category: .lexical, text: "改成過去式")
    }

    func makePersistence(inputZh: String = "你好", inputEn: String = "I go to school.") -> SpyWorkspaceStatePersistence {
        let encoder = JSONEncoder()
        let responseData = try! encoder.encode(sampleResponse)
        let hintsData = try! encoder.encode([sampleHint])
        return SpyWorkspaceStatePersistence(
            strings: [.inputZh: inputZh, .inputEn: inputEn],
            data: [.response: responseData, .practicedHints: hintsData],
            bools: [.showPracticedHints: true]
        )
    }

    func makeBankItem(id: String = UUID().uuidString) -> BankItem {
        BankItem(
            id: id,
            zh: "請翻譯：昨天我去了學校。",
            hints: [sampleHint],
            suggestions: [],
            suggestion: "描述昨天的活動",
            tags: ["review"],
            difficulty: 2,
            completed: nil
        )
    }
}

// MARK: - Tests

@MainActor
@Suite("CorrectionViewModel")
struct CorrectionViewModelTests {

    @Test("Initialization restores persisted state")
    func initializationRestoresState() {
        let persistence = makePersistence()
        let runner = UnusedCorrectionRunner()

        let viewModel = CorrectionViewModel(
            correctionRunner: runner,
            persistence: persistence,
            workspaceID: "ws-init"
        )

        #expect(viewModel.inputZh == "你好")
        #expect(viewModel.inputEn == "I go to school.")
        #expect(viewModel.response == sampleResponse)
        #expect(viewModel.practicedHints == [sampleHint])
        #expect(viewModel.showPracticedHints)

        let expectedHighlights = Highlighter.computeHighlights(text: viewModel.inputEn, errors: sampleResponse.errors)
        let expectedCorrected = Highlighter.computeHighlightsInCorrected(text: sampleResponse.corrected, errors: sampleResponse.errors)

        #expect(viewModel.highlights == expectedHighlights)
        #expect(viewModel.correctedHighlights == expectedCorrected)
    }

    @Test("reset clears state and persistence")
    func resetClearsStateAndPersistence() {
        let persistence = makePersistence()
        let viewModel = CorrectionViewModel(
            correctionRunner: UnusedCorrectionRunner(),
            persistence: persistence,
            workspaceID: "ws-reset"
        )

        viewModel.filterType = .lexical
        viewModel.cardMode = .corrected
        viewModel.reset()

        #expect(viewModel.inputZh.isEmpty)
        #expect(viewModel.inputEn.isEmpty)
        #expect(viewModel.response == nil)
        #expect(viewModel.highlights.isEmpty)
        #expect(viewModel.correctedHighlights.isEmpty)
        #expect(viewModel.practicedHints.isEmpty)
        #expect(viewModel.showPracticedHints == false)
        #expect(viewModel.filterType == nil)
        #expect(viewModel.cardMode == .original)

        let expectedKeys: Set<WorkspaceStateKey> = [.inputZh, .inputEn, .response, .practicedHints, .showPracticedHints]
        let removed = Set(persistence.removedKeys)
        #expect(removed == expectedKeys)
        #expect(persistence.removeAllInvocations.contains { Set($0) == expectedKeys })
    }

    @Test("startLocalPractice resets session and requests focus")
    func startLocalPracticeResetsSession() {
        let persistence = makePersistence()
        let viewModel = CorrectionViewModel(
            correctionRunner: UnusedCorrectionRunner(),
            persistence: persistence,
            workspaceID: "ws-practice"
        )

        viewModel.inputEn = "Old input"
        viewModel.response = sampleResponse
        viewModel.highlights = [Highlight(id: UUID(), range: viewModel.inputEn.startIndex..<viewModel.inputEn.endIndex, type: .lexical)]
        viewModel.correctedHighlights = viewModel.highlights
        viewModel.filterType = .lexical
        viewModel.cardMode = .corrected

        let initialFocusSignal = viewModel.focusEnSignal
        let bankItem = makeBankItem()

        viewModel.startLocalPractice(bookName: "Book", item: bankItem, tag: "custom")

        #expect(viewModel.inputZh == bankItem.zh)
        #expect(viewModel.inputEn.isEmpty)
        #expect(viewModel.practicedHints == bankItem.hints)
        #expect(viewModel.showPracticedHints == false)
        #expect(viewModel.currentBankItemId == bankItem.id)
        #expect(viewModel.currentPracticeTag == "custom")
        #expect(viewModel.practiceSource == .local(bookName: "Book"))
        #expect(viewModel.response == nil)
        #expect(viewModel.highlights.isEmpty)
        #expect(viewModel.correctedHighlights.isEmpty)
        #expect(viewModel.filterType == nil)
        #expect(viewModel.cardMode == .original)
        #expect(viewModel.focusEnSignal == initialFocusSignal + 1)
    }

    @Test("loadNextPractice selects next unfinished item")
    func loadNextPracticeSelectsNext() async {
        UserDefaults.standard.removeObject(forKey: "local.bank.books")
        UserDefaults.standard.removeObject(forKey: "local.bank.progress")

        let persistence = SpyWorkspaceStatePersistence()
        let viewModel = CorrectionViewModel(
            correctionRunner: UnusedCorrectionRunner(),
            persistence: persistence,
            workspaceID: "ws-next"
        )

        let bankStore = LocalBankStore()
        let progressStore = LocalBankProgressStore()

        let firstItem = makeBankItem(id: "item-1")
        let secondItem = makeBankItem(id: "item-2")
        bankStore.addOrReplaceBook(name: "Book", items: [firstItem, secondItem])
        progressStore.markCompleted(book: "Book", itemId: firstItem.id, score: 90)

        viewModel.bindLocalBankStores(localBank: bankStore, progress: progressStore)
        viewModel.practiceSource = .local(bookName: "Book")
        viewModel.currentBankItemId = firstItem.id

        let previousSignal = viewModel.focusEnSignal
        await viewModel.loadNextPractice()

        #expect(viewModel.currentBankItemId == secondItem.id)
        #expect(viewModel.inputZh == secondItem.zh)
        #expect(viewModel.practicedHints == secondItem.hints)
        #expect(viewModel.currentPracticeTag == secondItem.tags?.first)
        #expect(viewModel.practiceSource == .local(bookName: "Book"))
        #expect(viewModel.response == nil)
        #expect(viewModel.focusEnSignal == previousSignal + 1)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("loadNextPractice reports missing practice source")
    func loadNextPracticeMissingSource() async {
        let viewModel = CorrectionViewModel(
            correctionRunner: UnusedCorrectionRunner(),
            persistence: SpyWorkspaceStatePersistence(),
            workspaceID: "ws-missing-source"
        )

        await viewModel.loadNextPractice()

        #expect(viewModel.errorMessage == String(localized: "practice.error.notLocal"))
    }

    @Test("loadNextPractice reports missing stores")
    func loadNextPracticeMissingStores() async {
        let viewModel = CorrectionViewModel(
            correctionRunner: UnusedCorrectionRunner(),
            persistence: SpyWorkspaceStatePersistence(),
            workspaceID: "ws-missing-stores"
        )

        viewModel.practiceSource = .local(bookName: "Book")

        await viewModel.loadNextPractice()

        #expect(viewModel.errorMessage == String(localized: "practice.error.storeMissing"))
    }

    @Test("applySuggestion updates text and highlights")
    func applySuggestionUpdatesState() {
        let persistence = makePersistence()
        let viewModel = CorrectionViewModel(
            correctionRunner: UnusedCorrectionRunner(),
            persistence: persistence,
            workspaceID: "ws-suggestion"
        )

        viewModel.inputEn = "I go to school."
        viewModel.response = sampleResponse

        viewModel.applySuggestion(for: sampleError)

        #expect(viewModel.inputEn == "I went to school.")
        #expect(viewModel.highlights.isEmpty)

        let expectedCorrected = Highlighter.computeHighlightsInCorrected(text: sampleResponse.corrected, errors: sampleResponse.errors)
        #expect(viewModel.correctedHighlights == expectedCorrected)
    }

    @Test("savePracticeRecord persists record and marks progress")
    func savePracticeRecordPersists() {
        let repository = TestPracticeRecordsRepository()
        let store = PracticeRecordsStore(repository: repository)
        let persistence = SpyWorkspaceStatePersistence()
        let viewModel = CorrectionViewModel(
            correctionRunner: UnusedCorrectionRunner(),
            persistence: persistence,
            workspaceID: "ws-save"
        )

        let bankStore = LocalBankStore()
        let progressStore = LocalBankProgressStore()
        let bankItem = makeBankItem(id: "practice-item")
        bankStore.addOrReplaceBook(name: "Book", items: [bankItem])

        viewModel.bindLocalBankStores(localBank: bankStore, progress: progressStore)
        viewModel.bindPracticeRecordsStore(store)

        viewModel.startLocalPractice(bookName: "Book", item: bankItem)
        viewModel.inputEn = "I go to school."
        viewModel.response = sampleResponse

        var receivedNotification: Notification?
        let observer = NotificationCenter.default.addObserver(forName: .practiceRecordSaved, object: nil, queue: nil) { notification in
            receivedNotification = notification
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        viewModel.savePracticeRecord()

        #expect(store.records.count == 1)
        let record = store.records.first
        #expect(record?.bankItemId == bankItem.id)
        #expect(record?.bankBookName == "Book")
        #expect(record?.practiceTag == bankItem.tags?.first)
        #expect(record?.chineseText == bankItem.zh)
        #expect(record?.englishInput == "I go to school.")
        #expect(record?.hints == bankItem.hints)
        #expect(record?.teacherSuggestion == bankItem.suggestion)
        #expect(record?.correctedText == sampleResponse.corrected)
        #expect(record?.score == sampleResponse.score)
        #expect(record?.errors == sampleResponse.errors)
        #expect(progressStore.isCompleted(book: "Book", itemId: bankItem.id))

        #expect(repository.savedSnapshots.last?.count == 1)
        #expect(repository.savedSnapshots.last?.first == record)

        #expect(receivedNotification?.userInfo?["score"] as? Int == sampleResponse.score)
        #expect(receivedNotification?.userInfo?["errors"] as? Int == sampleResponse.errors.count)
    }

    @Test("savePracticeRecord ignores when response missing")
    func savePracticeRecordWithoutResponse() {
        let repository = TestPracticeRecordsRepository()
        let store = PracticeRecordsStore(repository: repository)
        let viewModel = CorrectionViewModel(
            correctionRunner: UnusedCorrectionRunner(),
            persistence: SpyWorkspaceStatePersistence(),
            workspaceID: "ws-save-missing"
        )

        viewModel.bindPracticeRecordsStore(store)
        viewModel.savePracticeRecord()

        #expect(store.records.isEmpty)
        #expect(repository.savedSnapshots.isEmpty)
    }

    @Test("savePracticeRecord ignores when store missing")
    func savePracticeRecordWithoutStore() {
        let viewModel = CorrectionViewModel(
            correctionRunner: UnusedCorrectionRunner(),
            persistence: SpyWorkspaceStatePersistence(),
            workspaceID: "ws-save-no-store"
        )

        viewModel.response = sampleResponse
        viewModel.savePracticeRecord()

        // Nothing to assert beyond ensuring no crash; verification handled implicitly.
    }
}

