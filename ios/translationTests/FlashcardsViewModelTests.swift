import Foundation
import Testing
@testable import translation

private struct TestCardData {
    static let cards: [Flashcard] = [
        Flashcard(front: "Front 1", back: "Back1"),
        Flashcard(front: "Front 2", back: "Back2")
    ]
}

@MainActor
final class TestAudioController: FlashcardsAudioController {
    var simulatedActive = false
    var stopPlaybackCalled = false
    var speakCalls: [String] = []

    init(viewModel: FlashcardsViewModel, active: Bool = false) {
        simulatedActive = active
        super.init(viewModel: viewModel)
    }

    override var isActive: Bool { simulatedActive }

    override func stopPlayback() {
        stopPlaybackCalled = true
        simulatedActive = false
    }

    override func speak(text: String, lang: String) {
        speakCalls.append(text)
    }

    override func startTTS(with settings: TTSSettings) {
        simulatedActive = true
    }
}

@MainActor
final class FlashcardsViewModelTests {
    private func makeViewModel(cards: [Flashcard] = TestCardData.cards) -> FlashcardsViewModel {
        let store = FlashcardsStore(cards: cards, startIndex: 0)
        let viewModel = FlashcardsViewModel(
            store: store,
            title: "Test",
            cards: cards,
            deckID: UUID(),
            startEditingOnAppear: false
        )
        return viewModel
    }

    @Test func flipStopsPlaybackWhenActive() async throws {
        let viewModel = makeViewModel()
        let testAudio = TestAudioController(viewModel: viewModel, active: true)
        viewModel.audio = testAudio

        let initialFace = viewModel.store.showBack
        viewModel.flipCurrentCard()

        #expect(viewModel.store.showBack == !initialFace)
        #expect(testAudio.stopPlaybackCalled)
        #expect(testAudio.simulatedActive == false)
        #expect(testAudio.speakCalls.isEmpty)
    }

    @Test func flipDoesNotTriggerAudioWhenInactive() async throws {
        let viewModel = makeViewModel()
        let testAudio = TestAudioController(viewModel: viewModel, active: false)
        viewModel.audio = testAudio

        viewModel.flipCurrentCard()

        #expect(testAudio.stopPlaybackCalled == false)
        #expect(testAudio.speakCalls.isEmpty)
    }

    @Test func annotateFlowMarksFamiliar() async throws {
        let viewModel = makeViewModel()
        let progressStore = FlashcardProgressStore()
        progressStore.clearAll()

        viewModel.beginReviewCycle(progressStore: progressStore)
        viewModel.adjustProficiency(.familiar, mode: .annotate, progressStore: progressStore)

        #expect(viewModel.sessionRightCount == 1)
        #expect(progressStore.isFamiliar(deckID: viewModel.deckID!, cardID: viewModel.store.current!.id))
    }
}
