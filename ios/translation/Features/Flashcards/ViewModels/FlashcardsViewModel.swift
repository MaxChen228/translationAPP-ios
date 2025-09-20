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

    let title: String
    let deckID: UUID?
    let originalCards: [Flashcard]
    let startEditingOnAppear: Bool
    let speechManager = FlashcardSpeechManager()
    let store: FlashcardsStore

    enum ReviewPhase { case allOnce, unfamiliarLoop }

    init(title: String,
         cards: [Flashcard],
         deckID: UUID?,
         startIndex: Int,
         startEditingOnAppear: Bool) {
        self.title = title
        self.originalCards = cards
        self.deckID = deckID
        self.startEditingOnAppear = startEditingOnAppear
        self.store = FlashcardsStore(cards: cards, startIndex: startIndex)
    }

    var isAudioActive: Bool { speechManager.isPlaying || speechManager.isPaused }

    func handleOnAppear(progressStore: FlashcardProgressStore) {
        if startEditingOnAppear, !didAutoStartEditing, store.current != nil {
            didAutoStartEditing = true
            beginEdit()
        }

        phase = .allOnce
        collectedUnfamiliar.removeAll()
        sessionRightCount = 0
        sessionWrongCount = 0
        applyUnfamiliarFilterIfNeeded(progressStore: progressStore)
    }

    func updateSwipePreview(mode: FlashcardsReviewMode, offset: CGFloat, threshold: CGFloat) {
        guard mode == .annotate else {
            swipePreview = nil
            return
        }
        if offset > threshold {
            swipePreview = .familiar
        } else if offset < -threshold {
            swipePreview = .unfamiliar
        } else {
            swipePreview = nil
        }
    }

    func beginEdit() {
        guard let card = store.current else { return }
        draft = card
        errorText = nil
        DSMotion.run(DS.AnimationToken.subtle) { isEditing = true }
        store.showBack = false
    }

    func cancelEdit() {
        draft = nil
        errorText = nil
        DSMotion.run(DS.AnimationToken.subtle) { isEditing = false }
    }

    func saveEdit(decksStore: FlashcardDecksStore, locale: Locale) {
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
        if let deckID { decksStore.updateCard(in: deckID, card: draftCard) }
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

    func adjustProficiency(_ outcome: AnnotateFeedback, mode: FlashcardsReviewMode, progressStore: FlashcardProgressStore) {
        guard mode == .annotate else { return }
        guard let deckID, let current = store.current else { return }
        switch outcome {
        case .familiar:
            progressStore.markFamiliar(deckID: deckID, cardID: current.id)
            collectedUnfamiliar.remove(current.id)
            sessionRightCount &+= 1
            Haptics.success()
        case .unfamiliar:
            progressStore.markUnfamiliar(deckID: deckID, cardID: current.id)
            if phase == .allOnce { collectedUnfamiliar.insert(current.id) }
            sessionWrongCount &+= 1
            Haptics.warning()
        }
    }

    func advance(mode: FlashcardsReviewMode) -> Bool {
        guard !store.cards.isEmpty else { return false }
        if mode == .annotate {
            if store.index < store.cards.count - 1 {
                store.index += 1
                store.showBack = false
                return false
            }
            return true
        } else {
            store.next()
            return false
        }
    }

    func resetComposedBackCache() {
        currentBackComposed = ""
        currentBackComposedCardID = nil
    }

    func applyUnfamiliarFilterIfNeeded(progressStore: FlashcardProgressStore) {
        guard let deckID else { return }
        swipePreview = nil
        let preferredID: UUID? = (store.index < originalCards.count) ? originalCards[store.index].id : nil
        let filtered: [Flashcard] = originalCards.filter { !progressStore.isFamiliar(deckID: deckID, cardID: $0.id) }
        if filtered.isEmpty {
            showEmptyResetConfirm = true
            return
        }
        store.cards = filtered
        if let pid = preferredID, let idx = filtered.firstIndex(where: { $0.id == pid }) {
            store.index = idx
        } else {
            store.index = 0
        }
        store.showBack = false
    }

    func clearForDeckReset(progressStore: FlashcardProgressStore) {
        guard let deckID else { return }
        progressStore.clearDeck(deckID: deckID)
        applyUnfamiliarFilterIfNeeded(progressStore: progressStore)
    }

    func completeSession(bannerCenter: BannerCenter, locale: Locale, dismiss: @escaping () -> Void) {
        bannerCenter.show(title: String(localized: "flashcards.session.completed", locale: locale))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { dismiss() }
    }

    func recordBackComposition(for cardID: UUID, text: String) {
        currentBackComposed = text
        currentBackComposedCardID = cardID
    }

    func backTextToSpeak(for card: Flashcard) -> String {
        if let id = currentBackComposedCardID, id == card.id, !currentBackComposed.isEmpty {
            return currentBackComposed
        }
        return backImmediateText(for: card)
    }

    func backImmediateText(for card: Flashcard) -> String {
        let lines = PlaybackBuilder.buildBackLines(card.back, fill: speechManager.settings.variantFill)
        return lines.first ?? card.back
    }

    func startTTS(with settings: TTSSettings) {
        let queue = PlaybackBuilder.buildQueue(cards: store.cards, startIndex: store.index, settings: settings)
        speechManager.play(queue: queue)
        lastTTSSettings = settings
    }

    func speak(text: String, lang: String) {
        let rate = speechManager.settings.rate
        speechManager.speak(text: text, lang: lang, rate: rate, speech: speechManager.speechEngine)
        lastTTSSettings = speechManager.settings
    }

    func ttsToggle() {
        if speechManager.isPlaying && !speechManager.isPaused {
            speechManager.pause()
            return
        }
        if speechManager.isPlaying && speechManager.isPaused {
            speechManager.resume()
            return
        }
        startTTS(with: lastTTSSettings ?? speechManager.settings)
    }

    func ttsNextCard() {
        guard !store.cards.isEmpty else { return }
        store.next()
        store.showBack = false
        if let settings = lastTTSSettings {
            speechManager.stop()
            startTTS(with: settings)
        }
    }

    func ttsPrevCard() {
        guard !store.cards.isEmpty else { return }
        store.prev()
        store.showBack = false
        if let settings = lastTTSSettings {
            speechManager.stop()
            startTTS(with: settings)
        }
    }
}
