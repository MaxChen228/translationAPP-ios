import SwiftUI

extension FlashcardsViewModel {
    func updateSwipePreview(mode: FlashcardsReviewMode, offset: CGFloat, threshold: CGFloat) {
        review.updateSwipePreview(mode: mode, offset: offset, threshold: threshold)
    }

    func adjustProficiency(_ outcome: AnnotateFeedback, mode: FlashcardsReviewMode, progressStore: FlashcardProgressStore) {
        review.adjustProficiency(outcome, mode: mode, progressStore: progressStore)
    }

    @discardableResult
    func advance(mode: FlashcardsReviewMode) -> Bool {
        review.advance(mode: mode)
    }

    func beginReviewCycle(progressStore: FlashcardProgressStore) {
        review.beginReviewCycle(progressStore: progressStore)
    }

    func applyUnfamiliarFilterIfNeeded(progressStore: FlashcardProgressStore) {
        review.applyUnfamiliarFilterIfNeeded(progressStore: progressStore)
    }

    func clearForDeckReset(progressStore: FlashcardProgressStore) {
        review.clearForDeckReset(progressStore: progressStore)
    }

    func recordBackComposition(for cardID: UUID, text: String) {
        review.recordBackComposition(for: cardID, text: text)
    }

    func resetComposedBackCache() {
        review.resetComposedBackCache()
    }

    func completeSession(bannerCenter: BannerCenter, locale: Locale, dismiss: @escaping () -> Void) {
        review.completeSession(bannerCenter: bannerCenter, locale: locale, dismiss: dismiss)
    }
}
