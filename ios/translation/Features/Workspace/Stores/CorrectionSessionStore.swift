import Foundation
import SwiftUI

@MainActor
final class CorrectionSessionStore: ObservableObject {
    private let persistence: WorkspaceStatePersisting
    private let correctionRunner: CorrectionRunning
    private let workspaceID: String
    private var isRestoringState = true

    @Published var inputZh: String {
        didSet {
            if inputZh != oldValue {
                persistence.writeString(inputZh, key: .inputZh)
                if !isRestoringState { markResultUnsaved() }
            }
        }
    }

    @Published var inputEn: String {
        didSet {
            if inputEn != oldValue {
                persistence.writeString(inputEn, key: .inputEn)
                if !isRestoringState { markResultUnsaved() }
            }
        }
    }

    @Published private(set) var response: AIResponse? {
        didSet { persistResponse() }
    }

    @Published private(set) var isResultSaved: Bool

    @Published private(set) var highlights: [Highlight]
    @Published private(set) var correctedHighlights: [Highlight]
    @Published var selectedErrorID: UUID?
    @Published var filterType: ErrorType?
    @Published var popoverError: ErrorItem?
    @Published var cardMode: ResultSwitcherCard.Mode

    @Published var practicedHints: [BankHint] {
        didSet { persistHints() }
    }

    @Published var showPracticedHints: Bool {
        didSet {
            if showPracticedHints {
                persistence.writeBool(true, key: .showPracticedHints)
            } else {
                persistence.remove(.showPracticedHints)
            }
        }
    }

    init(
        persistence: WorkspaceStatePersisting,
        correctionRunner: CorrectionRunning,
        workspaceID: String
    ) {
        self.persistence = persistence
        self.correctionRunner = correctionRunner
        self.workspaceID = workspaceID

        let restoredZh = persistence.readString(.inputZh) ?? ""
        let restoredEn = persistence.readString(.inputEn) ?? ""
        self.inputZh = restoredZh
        self.inputEn = restoredEn

        if let data = persistence.readData(.response),
           let decoded = try? JSONDecoder().decode(AIResponse.self, from: data) {
            self.response = decoded
        } else {
            self.response = nil
        }

        if
            let hintsData = persistence.readData(.practicedHints),
            let decodedHints = try? JSONDecoder().decode([BankHint].self, from: hintsData)
        {
            self.practicedHints = decodedHints
        } else {
            self.practicedHints = []
        }

        self.showPracticedHints = persistence.readBool(.showPracticedHints)
        self.isResultSaved = persistence.readBool(.resultSaved)
        self.highlights = []
        self.correctedHighlights = []
        self.selectedErrorID = nil
        self.filterType = nil
        self.popoverError = nil
        self.cardMode = .original

        if let res = self.response, !restoredEn.isEmpty {
            self.highlights = Highlighter.computeHighlights(text: restoredEn, errors: res.errors)
            self.correctedHighlights = Highlighter.computeHighlightsInCorrected(text: res.corrected, errors: res.errors)
            self.selectedErrorID = res.errors.first?.id
        }

        isRestoringState = false
    }

    func markResultSaved() {
        guard !isResultSaved else { return }
        isResultSaved = true
        persistence.writeBool(true, key: .resultSaved)
    }

    func markResultUnsaved(force: Bool = false) {
        if force {
            if isResultSaved {
                isResultSaved = false
            }
            persistence.remove(.resultSaved)
            return
        }
        guard !isRestoringState, isResultSaved else { return }
        isResultSaved = false
        persistence.remove(.resultSaved)
    }

    func resetSession() {
        markResultUnsaved(force: true)
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
        persistence.removeAll([
            .inputZh,
            .inputEn,
            .response,
            .practicedHints,
            .showPracticedHints,
        ])
    }

    func prepareForPractice(zh: String, hints: [BankHint], suggestion: String?) {
        inputZh = zh
        practicedHints = hints
        showPracticedHints = false
        inputEn = ""
        response = nil
        highlights = []
        correctedHighlights = []
        selectedErrorID = nil
        filterType = nil
        cardMode = .original
        popoverError = nil
        currentSuggestion = suggestion
        markResultUnsaved(force: true)
    }

    func updateSuggestion(_ suggestion: String?) {
        if currentSuggestion != suggestion {
            currentSuggestion = suggestion
            if !isRestoringState { markResultUnsaved() }
        }
    }

    private(set) var currentBankItemId: String?
    func updateCurrentBankItem(id: String?) {
        currentBankItemId = id
    }

    private(set) var currentPracticeTag: String?
    func updateCurrentPracticeTag(_ tag: String?) {
        currentPracticeTag = tag
    }

    private(set) var currentSuggestion: String?

    func applySuggestion(for error: ErrorItem) {
        guard let suggestion = error.suggestion, !suggestion.isEmpty else { return }
        guard let range = Highlighter.range(for: error, in: inputEn) else { return }
        inputEn.replaceSubrange(range, with: suggestion)
        recomputeHighlights()
        if !isRestoringState { markResultUnsaved() }
    }

    func performCorrection(deviceId: String?) async throws -> AICorrectionResult {
        AppLog.aiInfo("CorrectionSessionStore: run correction (ws=\(workspaceID))")
        let result = try await correctionRunner.runCorrection(
            zh: inputZh,
            en: inputEn,
            bankItemId: currentBankItemId,
            deviceId: deviceId,
            hints: practicedHints,
            suggestion: currentSuggestion
        )

        response = result.response
        if let original = result.originalHighlights {
            highlights = original
        } else {
            highlights = Highlighter.computeHighlights(text: inputEn, errors: result.response.errors)
        }
        if let corrected = result.correctedHighlights {
            correctedHighlights = corrected
        } else {
            correctedHighlights = Highlighter.computeHighlightsInCorrected(text: result.response.corrected, errors: result.response.errors)
        }
        selectedErrorID = result.response.errors.first?.id
        markResultUnsaved()
        return result
    }

    func produceEmptyInputResponse() {
        let err = ErrorItem(
            id: UUID(),
            span: "",
            type: .pragmatic,
            explainZh: String(localized: "content.error.emptyInput"),
            suggestion: nil,
            hints: nil
        )
        let res = AIResponse(corrected: "", score: 0, errors: [err])
        response = res
        highlights = []
        correctedHighlights = []
        selectedErrorID = nil
        markResultUnsaved()
    }

    func filteredErrors() -> [ErrorItem] {
        guard let res = response else { return [] }
        guard let filter = filterType else { return res.errors }
        return res.errors.filter { $0.type == filter }
    }

    func filteredHighlights() -> [Highlight] {
        guard let filter = filterType else { return highlights }
        return highlights.filter { $0.type == filter }
    }

    func filteredCorrectedHighlights() -> [Highlight] {
        guard let filter = filterType else { return correctedHighlights }
        return correctedHighlights.filter { $0.type == filter }
    }

    func updateErrors(_ errors: [ErrorItem], selectedID: UUID?) {
        guard var res = response else { return }
        res.errors = errors
        response = res
        recomputeHighlights()
        selectedErrorID = selectedID
        if let filter = filterType, let id = selectedID,
           let merged = errors.first(where: { $0.id == id }),
           merged.type != filter {
            filterType = merged.type
        }
        markResultUnsaved()
    }

    private func recomputeHighlights() {
        guard let res = response else {
            highlights = []
            correctedHighlights = []
            return
        }
        highlights = Highlighter.computeHighlights(text: inputEn, errors: res.errors)
        correctedHighlights = Highlighter.computeHighlightsInCorrected(text: res.corrected, errors: res.errors)
    }

    private func persistResponse() {
        if let res = response, let data = try? JSONEncoder().encode(res) {
            persistence.writeData(data, key: .response)
        } else {
            persistence.remove(.response)
        }
    }

    private func persistHints() {
        if practicedHints.isEmpty {
            persistence.remove(.practicedHints)
            return
        }
        if let data = try? JSONEncoder().encode(practicedHints) {
            persistence.writeData(data, key: .practicedHints)
        }
    }
}
