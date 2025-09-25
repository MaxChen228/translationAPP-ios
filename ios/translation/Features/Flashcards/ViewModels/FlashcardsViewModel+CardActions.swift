import SwiftUI

extension FlashcardsViewModel {
    func handlePrevTapped(mode: FlashcardsReviewMode, progressStore: FlashcardProgressStore) {
        if mode == .annotate && !annotationHistory.isEmpty {
            rollbackLastAnnotation(progressStore: progressStore)
        }
        goToPreviousAnimated(restartAudio: isAudioActive)
    }

    func goToPreviousAnimated(restartAudio: Bool) {
        swipePreview = nil
        guard !session.isEmpty else { return }
        let direction: CGFloat = 1
        DSMotion.run(DS.AnimationToken.tossOut) { dragX = direction * 800 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard let self else { return }
            self.session.previous()
            self.session.resetShowBack()
            self.dragX = -direction * 450
            DSMotion.run(DS.AnimationToken.bouncy) { self.dragX = 0 }
            if restartAudio {
                self.audio.restartMaintainingSettings()
            }
        }
    }

    func flipCurrentCard() {
        session.flip()
        if isAudioActive {
            audio.stopPlayback()
        }
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

    func shuffleCards() {
        guard !session.cards.isEmpty else { return }
        let preferred = session.current?.id
        session.shuffle(prefer: preferred)
        swipePreview = nil
        session.resetShowBack()
        if isAudioActive {
            audio.restartMaintainingSettings()
        }
    }
}
