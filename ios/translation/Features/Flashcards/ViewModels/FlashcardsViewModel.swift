import SwiftUI

@MainActor
final class FlashcardsViewModel: ObservableObject {
    @Published var isEditing: Bool = false
    @Published var draft: Flashcard? = nil
    @Published var errorText: String? = nil
    @Published var showDeleteConfirm: Bool = false
    @Published var didAutoStartEditing: Bool = false
    @Published var dragX: CGFloat = 0
    @Published var swipePreview: AnnotateFeedback? = nil
    @Published var showSettings: Bool = false
    @Published var showAudioSheet: Bool = false
    @Published var lastTTSSettings: TTSSettings? = nil
    @Published var currentBackComposed: String = ""
    @Published var currentBackComposedCardID: UUID? = nil
    @Published var phase: ReviewPhase = .allOnce
    @Published var collectedUnfamiliar: Set<UUID> = []
    @Published var showEmptyResetConfirm: Bool = false
    @Published var sessionRightCount: Int = 0
    @Published var sessionWrongCount: Int = 0
    @Published var editingFamiliar: Bool? = nil
    @Published var llmInstruction: String = ""
    @Published var isGeneratingCard: Bool = false
    @Published var llmError: String? = nil

    // 操作歷史，用於支援 Back 按鈕回滾標注操作
    var annotationHistory: [(cardID: UUID, previousState: Bool?, action: AnnotateFeedback)] = []

    let title: String
    let deckID: UUID?
    let originalCards: [Flashcard]
    let startEditingOnAppear: Bool
    let session: FlashcardSessionStore

    var speechManager: FlashcardSpeechManager { GlobalAudioSessionManager.shared.speechManager }
    lazy var review = FlashcardsReviewCoordinator(viewModel: self)
    lazy var audio = FlashcardsAudioController(viewModel: self)

    enum ReviewPhase { case allOnce, unfamiliarLoop }

    func rollbackLastAnnotation(progressStore: FlashcardProgressStore) {
        guard !annotationHistory.isEmpty,
              let deckID = deckID else { return }

        let lastAction = annotationHistory.removeLast()

        if let previousState = lastAction.previousState {
            if previousState {
                progressStore.markFamiliar(deckID: deckID, cardID: lastAction.cardID)
            } else {
                progressStore.markUnfamiliar(deckID: deckID, cardID: lastAction.cardID)
            }
        }

        switch lastAction.action {
        case .familiar:
            sessionRightCount = max(0, sessionRightCount - 1)
            collectedUnfamiliar.insert(lastAction.cardID)
        case .unfamiliar:
            sessionWrongCount = max(0, sessionWrongCount - 1)
            if phase == .allOnce {
                collectedUnfamiliar.remove(lastAction.cardID)
            }
        }
    }

    init(session: FlashcardSessionStore,
         title: String,
         cards: [Flashcard],
         deckID: UUID?,
         startEditingOnAppear: Bool) {
        self.session = session
        self.title = title
        self.originalCards = cards
        self.deckID = deckID
        self.startEditingOnAppear = startEditingOnAppear
    }

    func handleOnAppear(progressStore: FlashcardProgressStore) {
        if startEditingOnAppear, !didAutoStartEditing, session.current != nil {
            didAutoStartEditing = true
            beginEdit(progressStore: progressStore)
        }
        beginReviewCycle(progressStore: progressStore)
    }

    func beginEdit(progressStore: FlashcardProgressStore? = nil) {
        guard let card = session.current else { return }
        draft = card
        errorText = nil
        llmInstruction = ""
        llmError = nil
        DSMotion.run(DS.AnimationToken.subtle) { isEditing = true }
        session.resetShowBack()
        if let deckID, let progressStore {
            editingFamiliar = progressStore.isFamiliar(deckID: deckID, cardID: card.id)
        } else {
            editingFamiliar = nil
        }
    }

    func cancelEdit() {
        draft = nil
        errorText = nil
        editingFamiliar = nil
        llmInstruction = ""
        llmError = nil
        DSMotion.run(DS.AnimationToken.subtle) { isEditing = false }
    }

    func saveEdit(decksStore: FlashcardDecksStore, progressStore: FlashcardProgressStore, locale: Locale) {
        guard let draftCard = draft else {
            cancelEdit()
            return
        }
        if let err = validationError(locale: locale) {
            errorText = err
            return
        }

        session.replaceCard(draftCard)

        if let deckID {
            decksStore.updateCard(in: deckID, card: draftCard)
            if let familiar = editingFamiliar {
                if familiar {
                    progressStore.markFamiliar(deckID: deckID, cardID: draftCard.id)
                } else {
                    progressStore.markUnfamiliar(deckID: deckID, cardID: draftCard.id)
                }
            }
        }
        cancelEdit()
    }

    func validationError(locale: Locale) -> String? {
        guard let draft else { return nil }
        if draft.front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return String(localized: "flashcards.validator.frontEmpty", locale: locale)
        }
        if draft.back.contains("\n") || draft.back.contains("\r") {
            return String(localized: "flashcards.validator.backSingleLine", locale: locale)
        }
        let open = draft.back.filter { $0 == "(" || $0 == "（" }.count
        let close = draft.back.filter { $0 == ")" || $0 == "）" }.count
        if open != close {
            return String(localized: "flashcards.validator.bracketsMismatch", locale: locale)
        }
        return nil
    }

    func deleteCurrent(decksStore: FlashcardDecksStore) {
        guard let current = draft ?? session.current else { return }
        session.removeCard(id: current.id)
        if let deckID { decksStore.deleteCard(from: deckID, cardID: current.id) }
        cancelEdit()
    }
}

extension FlashcardsViewModel {
    func generateCard(using service: FlashcardCompletionService, locale: Locale) async {
        guard let currentDraft = draft else {
            await MainActor.run {
                self.llmError = FlashcardCompletionError.noDraft.errorDescription
            }
            return
        }

        let trimmedFront = currentDraft.front.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedFront.isEmpty else {
            await MainActor.run {
                self.llmError = FlashcardCompletionError.emptyFront.errorDescription
            }
            return
        }

        let req = FlashcardCompletionRequest(
            card: .init(
                front: currentDraft.front,
                frontNote: currentDraft.frontNote,
                back: currentDraft.back,
                backNote: currentDraft.backNote
            ),
            instruction: llmInstruction.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : llmInstruction,
            deckName: deckID.flatMap { _ in title.isEmpty ? nil : title }
        )

        await MainActor.run {
            self.isGeneratingCard = true
            self.llmError = nil
        }

        do {
            let response = try await service.completeCard(req)
            await MainActor.run {
                self.draft?.front = response.front
                self.draft?.frontNote = response.frontNote
                self.draft?.back = response.back
                self.draft?.backNote = response.backNote
                self.isGeneratingCard = false
            }
        } catch {
            let message: String
            if let completionError = error as? FlashcardCompletionError {
                message = completionError.errorDescription ?? error.localizedDescription
            } else {
                message = error.localizedDescription
            }

            await MainActor.run {
                self.isGeneratingCard = false
                self.llmError = message
            }
        }
    }
}
