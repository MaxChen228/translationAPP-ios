import SwiftUI

@MainActor
class FlashcardsReviewCoordinator {
    private unowned let viewModel: FlashcardsViewModel

    init(viewModel: FlashcardsViewModel) {
        self.viewModel = viewModel
    }

    func updateSwipePreview(mode: FlashcardsReviewMode, offset: CGFloat, threshold: CGFloat) {
        guard mode == .annotate else {
            viewModel.swipePreview = nil
            return
        }
        if offset > threshold {
            viewModel.swipePreview = .familiar
        } else if offset < -threshold {
            viewModel.swipePreview = .unfamiliar
        } else {
            viewModel.swipePreview = nil
        }
    }

    func adjustProficiency(_ outcome: AnnotateFeedback, mode: FlashcardsReviewMode, progressStore: FlashcardProgressStore) {
        guard mode == .annotate else { return }
        guard let deckID = viewModel.deckID, let current = viewModel.store.current else { return }
        switch outcome {
        case .familiar:
            progressStore.markFamiliar(deckID: deckID, cardID: current.id)
            viewModel.collectedUnfamiliar.remove(current.id)
            viewModel.sessionRightCount &+= 1
            Haptics.success()
        case .unfamiliar:
            progressStore.markUnfamiliar(deckID: deckID, cardID: current.id)
            if viewModel.phase == .allOnce { viewModel.collectedUnfamiliar.insert(current.id) }
            viewModel.sessionWrongCount &+= 1
            Haptics.warning()
        }
    }

    @discardableResult
    func advance(mode: FlashcardsReviewMode) -> Bool {
        guard !viewModel.store.cards.isEmpty else { return false }
        if mode == .annotate {
            if viewModel.store.index < viewModel.store.cards.count - 1 {
                viewModel.store.index += 1
                viewModel.store.showBack = false
                return false
            }
            return true
        } else {
            viewModel.store.next()
            return false
        }
    }

    func beginReviewCycle(progressStore: FlashcardProgressStore) {
        viewModel.phase = .allOnce
        viewModel.collectedUnfamiliar.removeAll()
        viewModel.sessionRightCount = 0
        viewModel.sessionWrongCount = 0
        applyUnfamiliarFilterIfNeeded(progressStore: progressStore)
    }

    func applyUnfamiliarFilterIfNeeded(progressStore: FlashcardProgressStore) {
        guard let deckID = viewModel.deckID else { return }
        viewModel.swipePreview = nil
        let preferredID: UUID? = (viewModel.store.index < viewModel.originalCards.count) ? viewModel.originalCards[viewModel.store.index].id : nil
        let filtered: [Flashcard] = viewModel.originalCards.filter { !progressStore.isFamiliar(deckID: deckID, cardID: $0.id) }
        if filtered.isEmpty {
            viewModel.showEmptyResetConfirm = true
            return
        }
        viewModel.store.cards = filtered
        if let pid = preferredID, let idx = filtered.firstIndex(where: { $0.id == pid }) {
            viewModel.store.index = idx
        } else {
            viewModel.store.index = 0
        }
        viewModel.store.showBack = false
    }

    func clearForDeckReset(progressStore: FlashcardProgressStore) {
        guard let deckID = viewModel.deckID else { return }
        progressStore.clearDeck(deckID: deckID)
        applyUnfamiliarFilterIfNeeded(progressStore: progressStore)
    }

    func recordBackComposition(for cardID: UUID, text: String) {
        viewModel.currentBackComposed = text
        viewModel.currentBackComposedCardID = cardID
    }

    func resetComposedBackCache() {
        viewModel.currentBackComposed = ""
        viewModel.currentBackComposedCardID = nil
    }

    func completeSession(bannerCenter: BannerCenter, locale: Locale, dismiss: @escaping () -> Void) {
        bannerCenter.show(title: String(localized: "flashcards.session.completed", locale: locale))
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { dismiss() }
    }
}
