import Foundation
import SwiftUI
import Combine

@MainActor
final class FlashcardSpeechManager: ObservableObject, SpeechEngineDelegate {
    // Expose the underlying objects' Published properties
    @Published var isPlaying: Bool = false
    @Published var isPaused: Bool = false
    @Published var currentCardIndex: Int? = nil
    @Published var currentFace: SpeechFace? = nil

    // 卡片完成事件
    @Published var completedCardIndex: Int? = nil
    @Published var didCompleteAllCards: Bool = false

    // 用戶操作狀態，防止自動邏輯干擾
    private var userOperationInProgress: Bool = false

    // Underlying components
    let speechEngine = SpeechEngine()
    let ttsStore = TTSSettingsStore()
    let instantSpeaker = InstantSpeaker()

    private var cancellables = Set<AnyCancellable>()

    init() {
        // Set up delegate
        speechEngine.delegate = self

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

    // MARK: - User Operation Control

    func markUserOperationStart() {
        userOperationInProgress = true
        completedCardIndex = nil  // 清除待處理事件
    }

    func markUserOperationEnd() {
        userOperationInProgress = false
    }

    // MARK: - SpeechEngineDelegate

    func speechEngine(_ engine: SpeechEngine, didCompleteCardAt index: Int) {
        // 如果用戶正在操作，忽略自動完成事件
        guard !userOperationInProgress else { return }
        completedCardIndex = index
    }

    func speechEngineDidCompleteAllCards(_ engine: SpeechEngine) {
        guard !userOperationInProgress else { return }
        didCompleteAllCards = true
    }
}