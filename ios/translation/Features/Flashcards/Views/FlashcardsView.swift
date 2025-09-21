import SwiftUI

final class FlashcardsStore: ObservableObject {
    @Published var cards: [Flashcard]
    @Published var index: Int = 0
    @Published var showBack: Bool = false

    init(cards: [Flashcard] = FlashcardsStore.defaultCards, startIndex: Int = 0) {
        self.cards = cards
        let clamped = max(0, min(startIndex, max(0, cards.count - 1)))
        self.index = clamped
    }

    var current: Flashcard? { cards.isEmpty ? nil : cards[index] }

    func next() { guard !cards.isEmpty else { return }; index = (index + 1) % cards.count; showBack = false }
    func prev() { guard !cards.isEmpty else { return }; index = (index - 1 + cards.count) % cards.count; showBack = false }
    func flip() { showBack.toggle() }

    static var defaultCards: [Flashcard] {
        [
            Flashcard(
                front: String(localized: "flashcards.sample1.front"),
                back: String(localized: "flashcards.sample1.back"),
                frontNote: nil,
                backNote: localizedOptional("flashcards.sample1.backNote")
            ),
            Flashcard(
                front: String(localized: "flashcards.sample2.front"),
                back: String(localized: "flashcards.sample2.back"),
                frontNote: nil,
                backNote: localizedOptional("flashcards.sample2.backNote")
            ),
            Flashcard(
                front: String(localized: "flashcards.sample3.front"),
                back: String(localized: "flashcards.sample3.back"),
                frontNote: nil,
                backNote: localizedOptional("flashcards.sample3.backNote")
            )
        ]
    }

    private static func localizedOptional(_ key: String) -> String? {
        let value = Bundle.main.localizedString(forKey: key, value: "", table: nil)
        return value.isEmpty ? nil : value
    }

    // End of store helpers
}

struct FlashcardsView: View {
    @StateObject private var store: FlashcardsStore
    @StateObject private var viewModel: FlashcardsViewModel
    @ObservedObject private var speechManager: FlashcardSpeechManager
    @EnvironmentObject private var decksStore: FlashcardDecksStore
    @EnvironmentObject private var progressStore: FlashcardProgressStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    @AppStorage("flashcards.reviewMode") private var modeRaw: String = FlashcardsReviewMode.browse.storageValue
    private var mode: FlashcardsReviewMode {
        get { FlashcardsReviewMode.fromStorage(modeRaw) }
        set { modeRaw = newValue.storageValue }
    }
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    init(title: String = String(localized: "flashcards.title"), cards: [Flashcard] = FlashcardsStore.defaultCards, deckID: UUID? = nil, startIndex: Int = 0, startEditing: Bool = false) {
        let store = FlashcardsStore(cards: cards, startIndex: startIndex)
        let viewModel = FlashcardsViewModel(
            store: store,
            title: title,
            cards: cards,
            deckID: deckID,
            startEditingOnAppear: startEditing
        )
        _store = StateObject(wrappedValue: store)
        _viewModel = StateObject(wrappedValue: viewModel)
        _speechManager = ObservedObject(wrappedValue: viewModel.speechManager)
    }

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                FlashcardsTopBar(
                    width: geo.size.width,
                    index: store.index,
                    total: store.cards.count,
                    onClose: { dismiss() },
                    onOpenSettings: { viewModel.showSettings = true }
                )

                if let card = store.current {
                    if viewModel.isEditing {
                        ScrollView {
                            CardEditor(
                                draft: binding(\.draft),
                                errorText: binding(\.errorText),
                                onDelete: { viewModel.showDeleteConfirm = true }
                            )
                            HStack(spacing: DS.Spacing.md) {
                                Button(String(localized: "action.cancel", locale: locale)) { viewModel.cancelEdit() }
                                    .buttonStyle(DSSecondaryButton())
                                Button(String(localized: "action.save", locale: locale)) {
                                    viewModel.saveEdit(decksStore: decksStore, locale: locale)
                                }
                                .buttonStyle(DSPrimaryButton())
                                .disabled(viewModel.validationError(locale: locale) != nil)
                            }
                        }
                    } else {
                        if mode == .annotate {
                            let highlight = viewModel.swipePreview
                            HStack {
                                SideCountBadge(count: viewModel.sessionWrongCount, color: DS.Palette.warning, filled: highlight == .unfamiliar)
                                Spacer()
                                SideCountBadge(count: viewModel.sessionRightCount, color: DS.Palette.success, filled: highlight == .familiar)
                            }
                            .padding(.horizontal, DS.Spacing.lg)
                        }

                        ZStack {
                            let preview = (mode == .annotate) ? viewModel.swipePreview : nil
                            if mode == .annotate, let preview {
                                FlashcardsClassificationCard(label: preview.label, color: preview.color)
                                    .dsAnimation(DS.AnimationToken.subtle, value: preview)
                            } else {
                                FlashcardsFlipCard(isFlipped: store.showBack) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        FlashcardsMarkdownText(card.front)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        if let note = card.frontNote, !note.isEmpty {
                                            FlashcardsNoteText(text: note)
                                        }
                                    }
                                } back: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        VariantBracketComposerView(card.back, onComposedChange: { s in
                                            viewModel.recordBackComposition(for: card.id, text: s)
                                        })
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        if let note = card.backNote, !note.isEmpty {
                                            FlashcardsNoteText(text: note)
                                        }
                                    }
                                } overlay: {
                                    FlashcardsPlaySideButton(style: .outline, diameter: 28) {
                                        let manager = speechManager
                                        if store.showBack {
                                            let text = viewModel.backTextToSpeak(for: card)
                                            viewModel.speak(text: text, lang: manager.settings.backLang)
                                        } else {
                                            viewModel.speak(text: card.front, lang: manager.settings.frontLang)
                                        }
                                    }
                                }
                            }
                        }
                        .onTapGesture { viewModel.flipCurrentCard() }
                        .offset(x: viewModel.dragX)
                        .rotationEffect(.degrees(Double(max(-10, min(10, viewModel.dragX * 0.06)))))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(300, geo.size.height * 0.62))
                        .gesture(DragGesture(minimumDistance: 20)
                            .onChanged { value in
                                viewModel.dragX = value.translation.width
                                let threshold: CGFloat = 80
                                viewModel.updateSwipePreview(mode: mode, offset: viewModel.dragX, threshold: threshold)
                            }
                            .onEnded { value in
                                let translation = value.translation.width
                                let threshold: CGFloat = 80
                                if abs(translation) > threshold {
                                    let dir: CGFloat = translation > 0 ? 1 : -1
                                    let outcome: AnnotateFeedback = dir > 0 ? .familiar : .unfamiliar
                                    DSMotion.run(DS.AnimationToken.tossOut) { viewModel.dragX = dir * 800 }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                        if mode == .annotate {
                                            viewModel.adjustProficiency(outcome, mode: mode, progressStore: progressStore)
                                        }
                                        viewModel.swipePreview = nil
                                        let reachedEnd = viewModel.advance(mode: mode)
                                        store.showBack = false
                                        viewModel.dragX = -dir * 450
                                        DSMotion.run(DS.AnimationToken.bouncy) { viewModel.dragX = 0 }
                                        if reachedEnd {
                                            viewModel.completeSession(
                                                bannerCenter: bannerCenter,
                                                locale: locale,
                                                dismiss: { dismiss() }
                                            )
                                        }
                                    }
                                } else {
                                    DSMotion.run(DS.AnimationToken.bouncy) { viewModel.dragX = 0 }
                                    viewModel.swipePreview = nil
                                }
                            })

                        Spacer(minLength: DS.Spacing.md)

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
                                style: .filled,
                                size: 44
                            )
                        }
                        .padding(.horizontal, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.lg)
                    }
                } else {
                    EmptyState()
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, viewModel.isAudioActive ? DS.Spacing.xl : DS.Spacing.lg)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .background(DS.Palette.background)
            .dsAnimation(DS.AnimationToken.subtle, value: viewModel.isAudioActive)
        }
        // Use custom top bar; hide system navigation chrome
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbar { }
        .onAppear {
            viewModel.handleOnAppear(progressStore: progressStore)
        }
        .alert(Text("flashcards.alert.delete"), isPresented: binding(\.showDeleteConfirm)) {
            Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                viewModel.deleteCurrent(decksStore: decksStore)
            }
            Button(String(localized: "action.cancel", locale: locale), role: .cancel) {}
        }
        .sheet(isPresented: binding(\.showSettings)) {
            FlashcardsSettingsSheet(ttsStore: speechManager.ttsStore, onOpenAudio: { viewModel.showAudioSheet = true })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: binding(\.showAudioSheet)) {
            FlashcardsAudioSettingsSheet(store: speechManager.ttsStore) { settings in
                viewModel.startTTS(with: settings)
            }
            .presentationDetents([.height(360)])
        }
        .alert(Text("flashcards.emptyDeckReset.title"), isPresented: binding(\.showEmptyResetConfirm)) {
            Button(String(localized: "flashcards.emptyDeckReset.cancel", locale: locale), role: .cancel) { dismiss() }
            Button(String(localized: "flashcards.emptyDeckReset.reset", locale: locale), role: .destructive) {
                viewModel.clearForDeckReset(progressStore: progressStore)
            }
        } message: {
            Text("flashcards.emptyDeckReset.message")
        }
        // 移除底部迷你播放器，改用右下角播放按鈕
        .onChange(of: speechManager.currentCardIndex, initial: false) { _, newValue in
            if let v = newValue, v >= 0, v < store.cards.count {
                DSMotion.run(DS.AnimationToken.subtle) {
                    store.index = v
                    store.showBack = false
                }
            }
        }
        .onChange(of: speechManager.currentFace, initial: false) { _, face in
            switch face {
            case .front?:
                DSMotion.run(DS.AnimationToken.subtle) { store.showBack = false }
            case .back?:
                DSMotion.run(DS.AnimationToken.subtle) { store.showBack = true }
            default:
                break
            }
        }
        .onChange(of: store.index, initial: false) { _, _ in
            // New card selected: clear previous composed cache to avoid stale playback
            viewModel.resetComposedBackCache()
        }
    }
}

private extension FlashcardsView {
    func binding<Value>(_ keyPath: ReferenceWritableKeyPath<FlashcardsViewModel, Value>) -> Binding<Value> {
        Binding(
            get: { viewModel[keyPath: keyPath] },
            set: { viewModel[keyPath: keyPath] = $0 }
        )
    }
}


private struct EmptyState: View {
    @Environment(\.locale) private var locale
    var body: some View {
        DSCard {
            VStack(spacing: 8) {
                Image(systemName: "rectangle.on.rectangle.angled").font(.title)
                Text(String(localized: "flashcards.empty", locale: locale))
                    .dsType(DS.Font.section)
                    .fontWeight(.semibold)
                Text(String(localized: "flashcards.empty.hint", locale: locale))
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.lg)
        }
    }
}

#Preview { NavigationStack { FlashcardsView() } }
