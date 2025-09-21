import SwiftUI

extension FlashcardsViewModel {
    func handlePrevTapped() {
        goToPreviousAnimated(restartAudio: isAudioActive)
    }

    func goToPreviousAnimated(restartAudio: Bool) {
        swipePreview = nil
        guard !store.cards.isEmpty else { return }
        let direction: CGFloat = 1
        DSMotion.run(DS.AnimationToken.tossOut) { dragX = direction * 800 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { [weak self] in
            guard let self else { return }
            self.store.prev()
            self.store.showBack = false
            self.dragX = -direction * 450
            DSMotion.run(DS.AnimationToken.bouncy) { self.dragX = 0 }
            if restartAudio {
                self.audio.restartMaintainingSettings()
            }
        }
    }

    func flipCurrentCard() {
        store.flip()
        if isAudioActive {
            audio.stopPlayback()
            return
        }
        guard let card = store.current else { return }
        let manager = speechManager
        if store.showBack {
            let text = backTextToSpeak(for: card)
            speak(text: text, lang: manager.settings.backLang)
        } else {
            speak(text: card.front, lang: manager.settings.frontLang)
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
}
