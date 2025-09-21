import SwiftUI

extension FlashcardsViewModel {
    var isAudioActive: Bool { audio.isActive }

    func startTTS(with settings: TTSSettings) {
        audio.startTTS(with: settings)
    }

    func speak(text: String, lang: String) {
        audio.speak(text: text, lang: lang)
    }

    func ttsToggle() {
        audio.toggle()
    }

    func ttsNextCard() {
        audio.jumpForward()
    }

    func ttsPrevCard() {
        audio.jumpBackward()
    }
}
