import Foundation
import Testing
@testable import translation

@MainActor
struct CorrectionViewModelTests {
    @Test("runCorrection updates state and posts completion notification")
    func testRunCorrectionSuccess() async throws {
        let persistence = MockPersistence()
        let practiceSession = MockPracticeSession()
        let serviceAdapter = MockServiceAdapter()
        let viewModel = CorrectionViewModel(
            workspaceID: "ws",
            persistence: persistence,
            serviceAdapter: serviceAdapter,
            practiceSession: practiceSession
        )

        viewModel.inputZh = "中文"
        viewModel.inputEn = "This is error"
        let range = viewModel.inputEn.range(of: "error")!
        let highlight = Highlight(id: UUID(), range: range, type: .lexical)
        let error = ErrorItem(id: UUID(), span: "error", type: .lexical, explainZh: "說明", suggestion: nil, hints: nil)
        let response = AIResponse(corrected: "This is error", score: 95, errors: [error])
        serviceAdapter.result = CorrectionServiceResult(response: response, originalHighlights: [highlight], correctedHighlights: [highlight])

        var posted: [Notification.Name] = []
        let observer = NotificationCenter.default.addObserver(forName: nil, object: nil, queue: nil) { note in
            posted.append(note.name)
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        await viewModel.runCorrection()

        #expect(viewModel.response == response)
        #expect(viewModel.highlights.count == 1)
        #expect(viewModel.correctedHighlights.count == 1)
        #expect(viewModel.selectedErrorID == response.errors.first?.id)
        #expect(posted.contains(.correctionCompleted))
        #expect(serviceAdapter.received?.zh == "中文")
    }

    @Test("runCorrection failure posts error notification")
    func testRunCorrectionFailure() async {
        let persistence = MockPersistence()
        let practiceSession = MockPracticeSession()
        let serviceAdapter = MockServiceAdapter()
        serviceAdapter.error = NSError(domain: "test", code: 1)
        let viewModel = CorrectionViewModel(
            workspaceID: "ws",
            persistence: persistence,
            serviceAdapter: serviceAdapter,
            practiceSession: practiceSession
        )

        viewModel.inputZh = "中文"
        viewModel.inputEn = "Hello"

        var posted: [Notification.Name] = []
        let observer = NotificationCenter.default.addObserver(forName: nil, object: nil, queue: nil) { note in
            posted.append(note.name)
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        await viewModel.runCorrection()

        #expect(viewModel.errorMessage == serviceAdapter.error?.localizedDescription)
        #expect(posted.contains(.correctionFailed))
    }

    @Test("savePracticeRecord delegates to session and posts notification")
    func testSavePracticeRecord() {
        let persistence = MockPersistence()
        let practiceSession = MockPracticeSession()
        let serviceAdapter = MockServiceAdapter()
        let viewModel = CorrectionViewModel(
            workspaceID: "ws",
            persistence: persistence,
            serviceAdapter: serviceAdapter,
            practiceSession: practiceSession
        )

        let error = ErrorItem(id: UUID(), span: "err", type: .lexical, explainZh: "說明", suggestion: nil, hints: nil)
        let response = AIResponse(corrected: "Fixed", score: 88, errors: [error])
        viewModel.response = response
        viewModel.practicedHints = []
        practiceSession.saveRecordResult = PracticeRecord(
            chineseText: "中文",
            englishInput: "English",
            hints: [],
            teacherSuggestion: nil,
            correctedText: response.corrected,
            score: response.score,
            errors: response.errors
        )

        var posted: [Notification.Name] = []
        let observer = NotificationCenter.default.addObserver(forName: nil, object: nil, queue: nil) { note in
            posted.append(note.name)
        }
        defer { NotificationCenter.default.removeObserver(observer) }

        viewModel.savePracticeRecord()

        #expect(practiceSession.savedParameters.count == 1)
        #expect(posted.contains(.practiceRecordSaved))
    }
}

private final class MockPersistence: CorrectionPersistence {
    var state = CorrectionPersistenceState()

    func load() -> CorrectionPersistenceState { state }
    func saveInputZh(_ value: String) { state.inputZh = value }
    func saveInputEn(_ value: String) { state.inputEn = value }
    func saveResponse(_ response: AIResponse?) { state.response = response }
    func saveHints(_ hints: [BankHint]) { state.practicedHints = hints }
    func saveShowPracticedHints(_ value: Bool) { state.showPracticedHints = value }
    func clearAll() { state = CorrectionPersistenceState() }
}

private final class MockServiceAdapter: CorrectionServiceAdapter {
    var result: CorrectionServiceResult?
    var error: NSError?
    var received: (zh: String, en: String, hints: [BankHint], suggestion: String?)?

    func correct(zh: String, en: String, currentBankItemId: String?, hints: [BankHint], suggestion: String?) async throws -> CorrectionServiceResult {
        received = (zh, en, hints, suggestion)
        if let error { throw error }
        guard let result else { fatalError("Result not set") }
        return result
    }
}

private final class MockPracticeSession: CorrectionPracticeSession {
    var practiceSource: CorrectionPracticeSource? = nil
    var currentBankItemId: String? = nil
    var currentPracticeTag: String? = nil
    var currentSuggestion: String? = nil

    var savedParameters: [(response: AIResponse, zh: String, en: String, hints: [BankHint])] = []
    var saveRecordResult: PracticeRecord?

    func bindLocalStores(localBank: LocalBankStore, progress: LocalBankProgressStore) {}
    func bindPracticeRecordsStore(_ store: PracticeRecordsStore) {}
    func startLocalPractice(bookName: String, item: BankItem, tag: String?) -> CorrectionPracticeState {
        CorrectionPracticeState(
            inputZh: item.zh,
            inputEn: "",
            practicedHints: item.hints,
            showPracticedHints: false,
            response: nil,
            practiceSource: practiceSource,
            currentBankItemId: currentBankItemId,
            currentPracticeTag: currentPracticeTag,
            suggestion: currentSuggestion
        )
    }
    func loadNextPractice() async throws -> CorrectionPracticeState {
        throw CorrectionPracticeSessionError.noRemainingItems
    }

    func savePracticeRecord(response: AIResponse, inputZh: String, inputEn: String, hints: [BankHint]) throws -> PracticeRecord {
        savedParameters.append((response, inputZh, inputEn, hints))
        if let saveRecordResult { return saveRecordResult }
        return PracticeRecord(
            chineseText: inputZh,
            englishInput: inputEn,
            hints: hints,
            teacherSuggestion: currentSuggestion,
            correctedText: response.corrected,
            score: response.score,
            errors: response.errors
        )
    }

    func resetContext() {
        practiceSource = nil
        currentBankItemId = nil
        currentPracticeTag = nil
        currentSuggestion = nil
    }
}
