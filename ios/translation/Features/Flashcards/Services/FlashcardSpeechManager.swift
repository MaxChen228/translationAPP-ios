import Foundation
import SwiftUI
import Combine

@MainActor
final class FlashcardSpeechManager: ObservableObject {
    // Expose the underlying objects' Published properties
    @Published var isPlaying: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentCardIndex: Int? = nil
    @Published var currentFace: SpeechFace? = nil

    // Underlying components
    let speechEngine = SpeechEngine()
    let ttsStore = TTSSettingsStore()
    let instantSpeaker = InstantSpeaker()

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Monitor speech engine state changes
        speechEngine.$isPlaying
            .receive(on: DispatchQueue.main)
            .assign(to: \.isPlaying, on: self)
            .store(in: &cancellables)

        speechEngine.$isPaused
            .receive(on: DispatchQueue.main)
            .assign(to: \.isPaused, on: self)
            .store(in: &cancellables)

        speechEngine.$currentCardIndex
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentCardIndex, on: self)
            .store(in: &cancellables)

        speechEngine.$currentFace
            .receive(on: DispatchQueue.main)
            .assign(to: \.currentFace, on: self)
            .store(in: &cancellables)
    }

    // MARK: - Delegate Methods (Facade Pattern)

    var settings: TTSSettings {
        get { ttsStore.settings }
        set { ttsStore.settings = newValue }
    }

    func play(queue: [SpeechItem]) {
        speechEngine.play(queue: queue)
    }

    func pause() {
        speechEngine.pause()
    }

    func resume() {
        speechEngine.resume()
    }

    func stop() {
        speechEngine.stop()
    }

    func speak(text: String, lang: String, rate: Float, speech: SpeechEngine) {
        instantSpeaker.speak(text: text, lang: lang, rate: rate, speech: speech)
    }
}