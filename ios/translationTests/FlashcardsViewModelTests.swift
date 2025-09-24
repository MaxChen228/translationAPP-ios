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
        let session = FlashcardSessionStore(cards: cards, startIndex: 0)
        return FlashcardsViewModel(
            session: session,
            title: "Test",
            cards: cards,
            deckID: UUID(),
            startEditingOnAppear: false
        )
    }

    struct MockCompletionService: FlashcardCompletionService {
        enum Mode {
            case success(FlashcardCompletionResponse)
            case failure(Error)
        }

        var mode: Mode

        func completeCard(_ request: FlashcardCompletionRequest) async throws -> FlashcardCompletionResponse {
            switch mode {
            case .success(let response):
                return response
            case .failure(let error):
                throw error
            }
        }
    }

    @Test func flipStopsPlaybackWhenActive() async throws {
        let viewModel = makeViewModel()
        let testAudio = TestAudioController(viewModel: viewModel, active: true)
        viewModel.audio = testAudio

        let initialFace = viewModel.session.showBack
        viewModel.flipCurrentCard()

        #expect(viewModel.session.showBack == !initialFace)
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
        if let deckID = viewModel.deckID, let current = viewModel.session.current {
            #expect(progressStore.isFamiliar(deckID: deckID, cardID: current.id))
        } else {
            Issue.record("Deck ID or current card missing")
        }
    }

    @Test func generatorRequiresFront() async {
        let viewModel = makeViewModel()
        viewModel.beginEdit()
        viewModel.draft?.front = "  "

        await viewModel.generateCard(using: MockCompletionService(mode: .success(.init(front: "A", frontNote: nil, back: "B", backNote: nil))), locale: Locale(identifier: "en"))

        #expect(viewModel.llmError == FlashcardCompletionError.emptyFront.errorDescription)
        #expect(viewModel.isGeneratingCard == false)
    }

    @Test func generatorSuccessUpdatesDraft() async {
        let viewModel = makeViewModel()
        viewModel.beginEdit()
        viewModel.draft?.front = "新聞媒體"
        let mock = MockCompletionService(mode: .success(.init(front: "新聞媒體", frontNote: "Media", back: "news media", backNote: "")))

        await viewModel.generateCard(using: mock, locale: Locale(identifier: "zh-Hant"))

        #expect(viewModel.isGeneratingCard == false)
        #expect(viewModel.draft?.back == "news media")
        #expect(viewModel.llmError == nil)
    }

    @Test func generatorFailureSetsError() async {
        let viewModel = makeViewModel()
        viewModel.beginEdit()
        viewModel.draft?.front = "新聞媒體"
        let mock = MockCompletionService(mode: .failure(FlashcardCompletionError.rateLimited))

        await viewModel.generateCard(using: mock, locale: Locale(identifier: "zh-Hant"))

        #expect(viewModel.isGeneratingCard == false)
        #expect(viewModel.llmError == FlashcardCompletionError.rateLimited.errorDescription)
    }
}
