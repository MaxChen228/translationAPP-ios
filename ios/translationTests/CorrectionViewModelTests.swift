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

private struct StubCorrectionResult {
    let response: AIResponse
    let originalHighlights: [Highlight]?
    let correctedHighlights: [Highlight]?

    static func sample() -> StubCorrectionResult {
        let error = ErrorItem(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            span: "go",
            type: .lexical,
            explainZh: "使用過去式",
            suggestion: "went",
            hints: ErrorHints(before: "I ", after: " to", occurrence: nil)
        )
        let response = AIResponse(corrected: "I went to school.", score: 92, errors: [error])
        let highlights = Highlighter.computeHighlights(text: "I go to school.", errors: [error])
        let correctedHighlights = Highlighter.computeHighlightsInCorrected(text: response.corrected, errors: response.errors)
        return StubCorrectionResult(response: response, originalHighlights: highlights, correctedHighlights: correctedHighlights)
    }
}

@MainActor
private final class StubCorrectionRunner: CorrectionRunning {
    let result: StubCorrectionResult
    init(result: StubCorrectionResult) {
        self.result = result
    }

    func runCorrection(
        zh: String,
        en: String,
        bankItemId: String?,
        deviceId: String?,
        hints: [BankHint]?,
        suggestion: String?
    ) async throws -> AICorrectionResult {
        AICorrectionResult(
            response: result.response,
            originalHighlights: result.originalHighlights,
            correctedHighlights: result.correctedHighlights
        )
    }
}

@MainActor
private final class ThrowingCorrectionRunner: CorrectionRunning {
    enum RunnerError: Error { case failed }
    func runCorrection(
        zh: String,
        en: String,
        bankItemId: String?,
        deviceId: String?,
        hints: [BankHint]?,
        suggestion: String?
    ) async throws -> AICorrectionResult {
        throw RunnerError.failed
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

private extension BankHint {
    static let sampleID = UUID(uuidString: "AAAAAAAA-1111-2222-3333-BBBBBBBBBBBB")!
    static var sample: BankHint {
        BankHint(id: sampleID, category: .lexical, text: "改成過去式")
    }
}

private extension BankItem {
    static func make(id: String = UUID().uuidString) -> BankItem {
        BankItem(
            id: id,
            zh: "請翻譯：昨天我去了學校。",
            hints: [.sample],
            suggestions: [],
            suggestion: "描述昨天的活動",
            tags: ["review"],
            difficulty: 2,
            completed: nil
        )
    }
}

private extension CorrectionSessionStore {
    static func make(
        persistence: WorkspaceStatePersisting,
        runner: CorrectionRunning,
        workspaceID: String
    ) -> CorrectionSessionStore {
        CorrectionSessionStore(persistence: persistence, correctionRunner: runner, workspaceID: workspaceID)
    }
}

// MARK: - Session Store Tests

@MainActor
@Suite("CorrectionSessionStore")
struct CorrectionSessionStoreTests {
    @Test("Initialization restores persisted state")
    func initializationRestoresState() {
        let result = StubCorrectionResult.sample()
        let encoder = JSONEncoder()
        let responseData = try! encoder.encode(result.response)
        let hintsData = try! encoder.encode([BankHint.sample])
        let persistence = SpyWorkspaceStatePersistence(
            strings: [.inputZh: "你好", .inputEn: "I go to school."],
            data: [.response: responseData, .practicedHints: hintsData],
            bools: [.showPracticedHints: true]
        )

        let store = CorrectionSessionStore.make(
            persistence: persistence,
            runner: StubCorrectionRunner(result: result),
            workspaceID: "ws"
        )

        #expect(store.inputZh == "你好")
        #expect(store.inputEn == "I go to school.")
        #expect(store.response == result.response)
        #expect(store.practicedHints == [BankHint.sample])
        #expect(store.showPracticedHints)
        #expect(store.highlights == result.originalHighlights)
        #expect(store.correctedHighlights == result.correctedHighlights)
    }

    @Test("resetSession clears persisted keys")
    func resetSessionClearsPersistence() {
        let persistence = SpyWorkspaceStatePersistence(
            strings: [.inputZh: "你好", .inputEn: "Hello"],
            data: [.response: Data(), .practicedHints: Data()],
            bools: [.showPracticedHints: true]
        )
        let store = CorrectionSessionStore.make(
            persistence: persistence,
            runner: StubCorrectionRunner(result: StubCorrectionResult.sample()),
            workspaceID: "ws"
        )

        store.resetSession()

        #expect(store.inputZh.isEmpty)
        #expect(store.inputEn.isEmpty)
        #expect(store.response == nil)
        #expect(store.practicedHints.isEmpty)
        #expect(store.showPracticedHints == false)

        let expected: Set<WorkspaceStateKey> = [.inputZh, .inputEn, .response, .practicedHints, .showPracticedHints]
        #expect(Set(persistence.removedKeys) == expected)
        #expect(persistence.removeAllInvocations.contains { Set($0) == expected })
    }
}

// MARK: - Practice Coordinator Tests

@MainActor
@Suite("PracticeSessionCoordinator")
struct PracticeSessionCoordinatorTests {
    @Test("startLocalPractice populates session state")
    func startLocalPracticeUpdatesSession() {
        let session = CorrectionSessionStore.make(
            persistence: SpyWorkspaceStatePersistence(),
            runner: StubCorrectionRunner(result: StubCorrectionResult.sample()),
            workspaceID: "ws"
        )
        let coordinator = PracticeSessionCoordinator(session: session)
        let item = BankItem.make(id: "item-1")

        coordinator.startLocalPractice(bookName: "Book", item: item, tag: "custom")

        #expect(session.inputZh == item.zh)
        #expect(session.inputEn.isEmpty)
        #expect(session.practicedHints == item.hints)
        #expect(coordinator.practiceSource == .local(bookName: "Book"))
        #expect(coordinator.currentBankItemId == item.id)
        #expect(coordinator.currentPracticeTag == "custom")
    }

    @Test("loadNextPractice respects random practice filters")
    @MainActor
    func loadNextPracticeUsesRandomFilters() {
        UserDefaults.standard.removeObject(forKey: "local.bank.books")
        UserDefaults.standard.removeObject(forKey: "local.bank.progress")

        let session = CorrectionSessionStore.make(
            persistence: SpyWorkspaceStatePersistence(),
            runner: StubCorrectionRunner(result: StubCorrectionResult.sample()),
            workspaceID: "ws"
        )
        let coordinator = PracticeSessionCoordinator(session: session)
        let bankStore = LocalBankStore()
        let progressStore = LocalBankProgressStore()
        coordinator.setLocalStores(localBank: bankStore, progress: progressStore)

        let suiteName = "test.random.\(UUID().uuidString)"
        let randomDefaults = UserDefaults(suiteName: suiteName)!
        randomDefaults.removePersistentDomain(forName: suiteName)
        let randomStore = RandomPracticeStore(defaults: randomDefaults)
        randomStore.setSelectedBooks(["Book"])
        coordinator.setRandomPracticeStore(randomStore)

        let first = BankItem.make(id: "first")
        let second = BankItem.make(id: "second")
        bankStore.addOrReplaceBook(name: "Book", items: [first, second])
        coordinator.startLocalPractice(bookName: "Book", item: first, tag: first.tags?.first)
        progressStore.markCompleted(book: "Book", itemId: first.id, score: 90)

        try? coordinator.loadNextPractice()

        #expect(coordinator.currentBankItemId == second.id)
        #expect(session.inputZh == second.zh)
        #expect(session.practicedHints == second.hints)
    }

    @Test("savePracticeRecord persists and marks progress")
    func savePracticeRecordPersists() {
        let result = StubCorrectionResult.sample()
        let persistence = SpyWorkspaceStatePersistence()
        let session = CorrectionSessionStore.make(
            persistence: persistence,
            runner: StubCorrectionRunner(result: result),
            workspaceID: "ws"
        )
        let coordinator = PracticeSessionCoordinator(session: session)
        let repository = TestPracticeRecordsRepository()
        let recordsStore = PracticeRecordsStore(repository: repository)
        let bankStore = LocalBankStore()
        let progressStore = LocalBankProgressStore()
        coordinator.setLocalStores(localBank: bankStore, progress: progressStore)
        coordinator.setPracticeRecordsStore(recordsStore)

        let item = BankItem.make(id: "practice")
        bankStore.addOrReplaceBook(name: "Book", items: [item])
        coordinator.startLocalPractice(bookName: "Book", item: item, tag: item.tags?.first)
        session.inputEn = "I go to school."

        let record = try? coordinator.savePracticeRecord(currentInput: session.inputEn, response: result.response)

        #expect(record != nil)
        #expect(recordsStore.records.count == 1)
        #expect(progressStore.isCompleted(book: "Book", itemId: item.id))
    }
}

// MARK: - View Model Tests

@MainActor
@Suite("CorrectionViewModel")
struct CorrectionViewModelTests {
    @Test("reset clears session and practice state")
    func resetClearsState() {
        let result = StubCorrectionResult.sample()
        let viewModel = CorrectionViewModel(
            correctionRunner: StubCorrectionRunner(result: result),
            persistence: SpyWorkspaceStatePersistence(),
            workspaceID: "ws"
        )

        viewModel.session.inputZh = "你好"
        viewModel.session.inputEn = "Hello"
        viewModel.session.practicedHints = [.sample]
        viewModel.practice.startLocalPractice(bookName: "Book", item: .make(), tag: nil)
        viewModel.merge.begin(initial: nil)

        viewModel.reset()

        #expect(viewModel.session.inputZh.isEmpty)
        #expect(viewModel.session.inputEn.isEmpty)
        #expect(viewModel.session.practicedHints.isEmpty)
        #expect(viewModel.practice.practiceSource == nil)
        #expect(!viewModel.merge.isMergeMode)
    }

    @Test("runCorrection stores results in session")
    func runCorrectionUpdatesSession() async {
        let result = StubCorrectionResult.sample()
        let viewModel = CorrectionViewModel(
            correctionRunner: StubCorrectionRunner(result: result),
            persistence: SpyWorkspaceStatePersistence(),
            workspaceID: "ws"
        )
        viewModel.session.inputZh = "你好"
        viewModel.session.inputEn = "I go to school."

        await viewModel.runCorrection()

        #expect(viewModel.session.response == result.response)
        #expect(viewModel.session.highlights == result.originalHighlights)
        #expect(viewModel.session.correctedHighlights == result.correctedHighlights)
        #expect(viewModel.session.selectedErrorID == result.response.errors.first?.id)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("runCorrection surfaces errors")
    func runCorrectionSurfacesErrors() async {
        let viewModel = CorrectionViewModel(
            correctionRunner: ThrowingCorrectionRunner(),
            persistence: SpyWorkspaceStatePersistence(),
            workspaceID: "ws"
        )
        viewModel.session.inputZh = "你好"
        viewModel.session.inputEn = "Hello"

        await viewModel.runCorrection()

        #expect(viewModel.errorMessage != nil)
    }

    @Test("loadNextPractice sets error when source missing")
    func loadNextPracticeMissingSource() {
        let viewModel = CorrectionViewModel(
            correctionRunner: StubCorrectionRunner(result: StubCorrectionResult.sample()),
            persistence: SpyWorkspaceStatePersistence(),
            workspaceID: "ws"
        )

        viewModel.loadNextPractice()

        let expected = String(localized: String.LocalizationValue("practice.error.notLocal"))
        #expect(viewModel.errorMessage == expected)
    }
}
