import Foundation
import SwiftUI
import OSLog

@MainActor
final class CorrectionViewModel: ObservableObject {
    private let workspaceID: String
    private let persistence: CorrectionPersistence
    private let serviceAdapter: CorrectionServiceAdapter
    private let practiceSession: CorrectionPracticeSession

    @Published var inputZh: String = "" { didSet { if inputZh != oldValue { persistence.saveInputZh(inputZh) } } }
    @Published var inputEn: String = "" { didSet { if inputEn != oldValue { persistence.saveInputEn(inputEn) } } }

    @Published var response: AIResponse? { didSet { persistence.saveResponse(response) } }
    @Published var highlights: [Highlight] = []
    @Published var correctedHighlights: [Highlight] = []
    @Published var selectedErrorID: UUID?
    @Published var filterType: ErrorType? = nil
    @Published var popoverError: ErrorItem? = nil
    @Published var cardMode: ResultSwitcherCard.Mode = .original

    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    @Published var practicedHints: [BankHint] = [] { didSet { persistence.saveHints(practicedHints) } }
    @Published var showPracticedHints: Bool = false { didSet { persistence.saveShowPracticedHints(showPracticedHints) } }

    @Published var focusEnSignal: Int = 0

    @Published var currentBankItemId: String? = nil
    @Published var currentPracticeTag: String? = nil
    @Published var practiceSource: CorrectionPracticeSource? = nil

    init(
        workspaceID: String,
        persistence: CorrectionPersistence,
        serviceAdapter: CorrectionServiceAdapter,
        practiceSession: CorrectionPracticeSession
    ) {
        self.workspaceID = workspaceID
        self.persistence = persistence
        self.serviceAdapter = serviceAdapter
        self.practiceSession = practiceSession

        let restored = persistence.load()
        self.inputZh = restored.inputZh
        self.inputEn = restored.inputEn
        self.response = restored.response
        self.practicedHints = restored.practicedHints
        self.showPracticedHints = restored.showPracticedHints
        self.practiceSource = practiceSession.practiceSource
        self.currentBankItemId = practiceSession.currentBankItemId
        self.currentPracticeTag = practiceSession.currentPracticeTag

        if let res = self.response, !inputEn.isEmpty {
            self.highlights = Highlighter.computeHighlights(text: inputEn, errors: res.errors)
            self.correctedHighlights = Highlighter.computeHighlightsInCorrected(text: res.corrected, errors: res.errors)
        }

        AppLog.aiInfo("CorrectionViewModel initialized (ws=\(workspaceID)) with adapter: \(String(describing: type(of: serviceAdapter)))")
    }

    convenience init(service: AIService = AIServiceFactory.makeDefault(), workspaceID: String = "default") {
        let persistence = UserDefaultsCorrectionPersistence(workspaceID: workspaceID)
        let adapter = DefaultCorrectionServiceAdapter(service: service)
        let practiceSession = DefaultCorrectionPracticeSession()
        self.init(
            workspaceID: workspaceID,
            persistence: persistence,
            serviceAdapter: adapter,
            practiceSession: practiceSession
        )
    }

    func bindLocalBankStores(localBank: LocalBankStore, progress: LocalBankProgressStore) {
        practiceSession.bindLocalStores(localBank: localBank, progress: progress)
    }

    func bindPracticeRecordsStore(_ store: PracticeRecordsStore) {
        practiceSession.bindPracticeRecordsStore(store)
    }

    func reset() {
        inputZh = ""
        inputEn = ""
        response = nil
        highlights = []
        correctedHighlights = []
        selectedErrorID = nil
        filterType = nil
        popoverError = nil
        cardMode = .original
        practicedHints = []
        showPracticedHints = false
        practiceSource = nil
        currentBankItemId = nil
        currentPracticeTag = nil
        practiceSession.resetContext()
        persistence.clearAll()
    }

    func fillExample() {
        inputZh = String(localized: "content.sample.zh")
        inputEn = String(localized: "content.sample.en")
    }

    func requestFocusEn() {
        focusEnSignal &+= 1
    }

    func runCorrection() async {
        let user = inputEn.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty else {
            let err = ErrorItem(
                id: UUID(),
                span: "",
                type: .pragmatic,
                explainZh: String(localized: "content.error.emptyInput"),
                suggestion: nil,
                hints: nil
            )
            let res = AIResponse(corrected: "", score: 0, errors: [err])
            self.response = res
            self.highlights = []
            self.correctedHighlights = []
            self.selectedErrorID = nil
            return
        }

        if inputZh.isEmpty { inputZh = String(localized: "content.sample.zh") }

        isLoading = true
        errorMessage = nil
        do {
            AppLog.aiInfo("Start correction via adapter \(String(describing: type(of: serviceAdapter)))")
            let result = try await serviceAdapter.correct(
                zh: inputZh,
                en: inputEn,
                currentBankItemId: practiceSession.currentBankItemId,
                hints: practicedHints,
                suggestion: practiceSession.currentSuggestion
            )
            self.response = result.response
            self.highlights = result.originalHighlights
            self.correctedHighlights = result.correctedHighlights
            self.selectedErrorID = result.response.errors.first?.id
            NotificationCenter.default.post(name: .correctionCompleted, object: nil, userInfo: [
                AppEventKeys.workspaceID: self.workspaceID,
                AppEventKeys.score: self.response?.score ?? 0,
                AppEventKeys.errors: self.response?.errors.count ?? 0,
            ])
        } catch {
            self.errorMessage = (error as NSError).localizedDescription
            AppLog.aiError("Correction failed: \((error as NSError).localizedDescription)")
            NotificationCenter.default.post(name: .correctionFailed, object: nil, userInfo: [
                AppEventKeys.workspaceID: self.workspaceID,
                AppEventKeys.error: (error as NSError).localizedDescription
            ])
        }
        isLoading = false
    }

    func startLocalPractice(bookName: String, item: BankItem, tag: String? = nil) {
        let state = practiceSession.startLocalPractice(bookName: bookName, item: item, tag: tag)
        applyPracticeState(state)
        requestFocusEn()
    }

    func loadNextPractice() async {
        do {
            let state = try await practiceSession.loadNextPractice()
            await MainActor.run {
                self.applyPracticeState(state)
                self.errorMessage = nil
                self.requestFocusEn()
            }
        } catch let error as CorrectionPracticeSessionError {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
        } catch {
            await MainActor.run {
                self.errorMessage = (error as NSError).localizedDescription
            }
        }
    }

    var filteredErrors: [ErrorItem] {
        guard let res = response else { return [] }
        guard let f = filterType else { return res.errors }
        return res.errors.filter { $0.type == f }
    }

    var filteredHighlights: [Highlight] {
        guard let f = filterType else { return highlights }
        return highlights.filter { $0.type == f }
    }
    var filteredCorrectedHighlights: [Highlight] {
        guard let f = filterType else { return correctedHighlights }
        return correctedHighlights.filter { $0.type == f }
    }

    func applySuggestion(for error: ErrorItem) {
        guard let suggestion = error.suggestion, !suggestion.isEmpty else { return }
        guard let range = Highlighter.range(for: error, in: inputEn) else { return }
        inputEn.replaceSubrange(range, with: suggestion)
        if let res = response {
            self.highlights = Highlighter.computeHighlights(text: inputEn, errors: res.errors)
            self.correctedHighlights = Highlighter.computeHighlightsInCorrected(text: res.corrected, errors: res.errors)
        }
    }

    func savePracticeRecord() {
        guard let response = self.response else {
            AppLog.aiError("Cannot save practice record: no response available")
            return
        }

        do {
            let record = try practiceSession.savePracticeRecord(
                response: response,
                inputZh: inputZh,
                inputEn: inputEn,
                hints: practicedHints
            )
            NotificationCenter.default.post(name: .practiceRecordSaved, object: nil, userInfo: [
                "score": record.score,
                "errors": record.errors.count
            ])
        } catch {
            AppLog.aiError("Cannot save practice record: \(error.localizedDescription)")
        }
    }

    private func applyPracticeState(_ state: CorrectionPracticeState) {
        inputZh = state.inputZh
        practicedHints = state.practicedHints
        showPracticedHints = state.showPracticedHints
        inputEn = state.inputEn
        response = state.response
        highlights = []
        correctedHighlights = []
        selectedErrorID = nil
        filterType = nil
        popoverError = nil
        cardMode = .original
        practiceSource = state.practiceSource
        currentBankItemId = state.currentBankItemId
        currentPracticeTag = state.currentPracticeTag
    }
}
