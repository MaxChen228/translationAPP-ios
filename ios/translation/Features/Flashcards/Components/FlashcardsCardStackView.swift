import SwiftUI

struct FlashcardsCardStackView: View {
    let card: Flashcard
    let mode: FlashcardsReviewMode
    @ObservedObject var session: FlashcardSessionStore
    @ObservedObject var viewModel: FlashcardsViewModel
    @ObservedObject var speechManager: FlashcardSpeechManager
    let bannerCenter: BannerCenter
    let progressStore: FlashcardProgressStore
    let availableSize: CGSize
    let locale: Locale
    let dismiss: DismissAction

    private var showEditButton: Bool { viewModel.deckID != nil && !viewModel.isEditing }
    private var extraTopPadding: CGFloat { showEditButton ? DS.Spacing.xl : .zero }

    var body: some View {
        ZStack {
            let preview = (mode == .annotate) ? viewModel.swipePreview : nil
            if mode == .annotate, let preview {
                FlashcardsClassificationCard(label: preview.label, color: preview.color)
                    .dsAnimation(DS.AnimationToken.subtle, value: preview)
            } else {
                flipCard
            }
        }
        .onTapGesture { viewModel.flipCurrentCard() }
        .offset(x: viewModel.dragX)
        .rotationEffect(.degrees(Double(max(-10, min(10, viewModel.dragX * 0.06)))))
        .frame(maxWidth: .infinity)
        .frame(height: max(300, availableSize.height * 0.62))
        .gesture(dragGesture)
    }

    private var flipCard: some View {
        FlashcardsFlipCard(isFlipped: session.showBack) {
            VStack(alignment: .leading, spacing: 10) {
                FlashcardsMarkdownText(card.front)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let note = card.frontNote, !note.isEmpty {
                    FlashcardsNoteText(text: note)
                }
            }
            .padding(.top, extraTopPadding)
        } back: {
            VStack(alignment: .leading, spacing: 14) {
                Spacer(minLength: DS.Spacing.lg)
                VariantBracketComposerView(card.back, onComposedChange: { text in
                    viewModel.recordBackComposition(for: card.id, text: text)
                })
                .frame(maxWidth: .infinity, alignment: .center)
                Spacer(minLength: DS.Spacing.xl)
                if let note = card.backNote, !note.isEmpty {
                    Text(note)
                        .dsType(DS.Font.bodyEmph)
                        .foregroundStyle(.primary.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                Spacer(minLength: DS.Spacing.xl)
            }
            .padding(.top, extraTopPadding)
        } overlay: {
            overlayControls
        }
    }

    private var overlayControls: some View {
        ZStack {
            if showEditButton {
                DSQuickActionIconButton(
                    systemName: "square.and.pencil",
                    labelKey: "action.edit",
                    action: { viewModel.beginEdit(progressStore: progressStore) },
                    shape: .circle,
                    style: .outline,
                    size: 32
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, DS.Spacing.md)
                .padding(.trailing, DS.Spacing.md)
            }

            FlashcardsPlaySideButton(style: .outline, diameter: 28) {
                if session.showBack {
                    let text = viewModel.backTextToSpeak(for: card)
                    viewModel.speak(text: text, lang: speechManager.settings.backLang)
                } else {
                    viewModel.speak(text: card.front, lang: speechManager.settings.frontLang)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.bottom, DS.Spacing.md)
            .padding(.trailing, DS.Spacing.md)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                viewModel.dragX = value.translation.width
                let threshold: CGFloat = 80
                viewModel.updateSwipePreview(mode: mode, offset: viewModel.dragX, threshold: threshold)
            }
            .onEnded { value in
                let translation = value.translation.width
                let threshold: CGFloat = 80
                guard abs(translation) > threshold else {
                    DSMotion.run(DS.AnimationToken.bouncy) { viewModel.dragX = 0 }
                    viewModel.swipePreview = nil
                    return
                }

                let direction: CGFloat = translation > 0 ? 1 : -1
                let outcome: AnnotateFeedback = direction > 0 ? .familiar : .unfamiliar

                let wasAutoPlaying = speechManager.isPlaying
                if wasAutoPlaying {
                    speechManager.completedCardIndex = nil
                }

                DSMotion.run(DS.AnimationToken.tossOut) { viewModel.dragX = direction * 800 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                    if mode == .annotate {
                        viewModel.adjustProficiency(outcome, mode: mode, progressStore: progressStore)
                    }
                    viewModel.swipePreview = nil
                    let reachedEnd = viewModel.advance(mode: mode)
                    session.resetShowBack()
                    viewModel.dragX = -direction * 450
                    DSMotion.run(DS.AnimationToken.bouncy) { viewModel.dragX = 0 }

                    if wasAutoPlaying {
                        viewModel.audio.restartMaintainingSettings()
                    }

                    if reachedEnd {
                        viewModel.completeSession(
                            bannerCenter: bannerCenter,
                            locale: locale,
                            dismiss: { dismiss() }
                        )
                    }
                }
            }
    }
}
