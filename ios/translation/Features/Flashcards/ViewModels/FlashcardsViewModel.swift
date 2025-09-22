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

    // 操作歷史，用於支援 Back 按鈕回滾標注操作
    var annotationHistory: [(cardID: UUID, previousState: Bool?, action: AnnotateFeedback)] = []

    let title: String
    let deckID: UUID?
    let originalCards: [Flashcard]
    let startEditingOnAppear: Bool
    var speechManager: FlashcardSpeechManager { GlobalAudioSessionManager.shared.speechManager }
    lazy var review = FlashcardsReviewCoordinator(viewModel: self)
    lazy var audio = FlashcardsAudioController(viewModel: self)
    let store: FlashcardsStore

    enum ReviewPhase { case allOnce, unfamiliarLoop }

    func rollbackLastAnnotation(progressStore: FlashcardProgressStore) {
        guard !annotationHistory.isEmpty,
              let deckID = deckID else { return }

        let lastAction = annotationHistory.removeLast()

        // 回滾進度狀態
        if let previousState = lastAction.previousState {
            if previousState {
                progressStore.markFamiliar(deckID: deckID, cardID: lastAction.cardID)
            } else {
                progressStore.markUnfamiliar(deckID: deckID, cardID: lastAction.cardID)
            }
        }

        // 回滾計數器
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

    init(store: FlashcardsStore,
         title: String,
         cards: [Flashcard],
         deckID: UUID?,
         startEditingOnAppear: Bool) {
        self.store = store
        self.title = title
        self.originalCards = cards
        self.deckID = deckID
        self.startEditingOnAppear = startEditingOnAppear
    }

    func handleOnAppear(progressStore: FlashcardProgressStore) {
        if startEditingOnAppear, !didAutoStartEditing, store.current != nil {
            didAutoStartEditing = true
            beginEdit(progressStore: progressStore)
        }
        beginReviewCycle(progressStore: progressStore)
    }

    func beginEdit(progressStore: FlashcardProgressStore? = nil) {
        guard let card = store.current else { return }
        draft = card
        errorText = nil
        DSMotion.run(DS.AnimationToken.subtle) { isEditing = true }
        store.showBack = false
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
        if let idx = store.cards.firstIndex(where: { $0.id == draftCard.id }) {
            store.cards[idx] = draftCard
        }
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
        guard let current = draft ?? store.current else { return }
        if let idx = store.cards.firstIndex(where: { $0.id == current.id }) {
            store.cards.remove(at: idx)
            if store.index >= store.cards.count {
                store.index = max(0, store.cards.count - 1)
            }
        }
        if let deckID { decksStore.deleteCard(from: deckID, cardID: current.id) }
        cancelEdit()
    }
}
