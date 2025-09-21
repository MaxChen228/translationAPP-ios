import SwiftUI

@MainActor
class FlashcardsAudioController {
    private unowned let viewModel: FlashcardsViewModel
    private var globalAudio: GlobalAudioSessionManager { GlobalAudioSessionManager.shared }
    private var speechManager: FlashcardSpeechManager { viewModel.speechManager }

    init(viewModel: FlashcardsViewModel) {
        self.viewModel = viewModel
    }

    var isActive: Bool { speechManager.isPlaying || speechManager.isPaused }

    func startTTS(with settings: TTSSettings) {
        let queue = PlaybackBuilder.buildQueue(cards: viewModel.store.cards, startIndex: viewModel.store.index, settings: settings)
        speechManager.play(queue: queue)
        viewModel.lastTTSSettings = settings
    }

    func speak(text: String, lang: String) {
        let rate = speechManager.settings.rate
        speechManager.speak(text: text, lang: lang, rate: rate, speech: speechManager.speechEngine)
        viewModel.lastTTSSettings = speechManager.settings
    }

    func toggle() {
        if speechManager.isPlaying && !speechManager.isPaused {
            speechManager.pause()
            return
        }
        if speechManager.isPlaying && speechManager.isPaused {
            speechManager.resume()
            return
        }
        startTTS(with: viewModel.lastTTSSettings ?? speechManager.settings)
    }

    func jumpForward() {
        guard !viewModel.store.cards.isEmpty else { return }

        // 清除待處理的播放完成事件，防止衝突
        speechManager.completedCardIndex = nil
        speechManager.didCompleteAllCards = false

        viewModel.store.next()
        viewModel.store.showBack = false
        restartMaintainingSettings()
    }

    func jumpBackward() {
        guard !viewModel.store.cards.isEmpty else { return }

        // 清除待處理的播放完成事件，防止衝突
        speechManager.completedCardIndex = nil
        speechManager.didCompleteAllCards = false

        viewModel.store.prev()
        viewModel.store.showBack = false
        restartMaintainingSettings()
    }

    func restartMaintainingSettings() {
        guard isActive else { return }
        let settings = viewModel.lastTTSSettings ?? speechManager.settings
        speechManager.stop()
        startTTS(with: settings)
    }

    func stopPlayback() {
        guard isActive else { return }
        speechManager.stop()
    }
}
