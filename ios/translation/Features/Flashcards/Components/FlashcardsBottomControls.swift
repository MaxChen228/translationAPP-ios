import SwiftUI

struct FlashcardsBottomControls: View {
    let mode: FlashcardsReviewMode
    @ObservedObject var viewModel: FlashcardsViewModel
    @ObservedObject var speechManager: FlashcardSpeechManager
    let progressStore: FlashcardProgressStore

    var body: some View {
        HStack {
            DSQuickActionIconButton(
                systemName: "arrow.uturn.left",
                labelKey: "flashcards.prev",
                action: { viewModel.handlePrevTapped(mode: mode, progressStore: progressStore) },
                shape: .circle,
                style: .outline,
                size: 44
            )

            Spacer()

            DSQuickActionIconButton(
                systemName: (speechManager.isPlaying && !speechManager.isPaused) ? "pause.fill" : "play.fill",
                labelKey: (speechManager.isPlaying && !speechManager.isPaused) ? "tts.pause" : "tts.play",
                action: { viewModel.ttsToggle() },
                shape: .circle,
                style: .outline,
                size: 48
            )
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.bottom, DS.Spacing.lg)
    }
}
