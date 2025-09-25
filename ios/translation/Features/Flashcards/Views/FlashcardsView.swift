import SwiftUI

struct FlashcardsView: View {
    @StateObject private var session: FlashcardSessionStore
    @StateObject private var viewModel: FlashcardsViewModel
    @ObservedObject private var speechManager: FlashcardSpeechManager
    @ObservedObject private var globalAudio = GlobalAudioSessionManager.shared
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
    private let completionService: FlashcardCompletionService

    init(title: String = String(localized: "flashcards.title"), cards: [Flashcard] = FlashcardSessionStore.defaultCards, deckID: UUID? = nil, startIndex: Int = 0, startEditing: Bool = false, completionService: FlashcardCompletionService = FlashcardCompletionServiceFactory.makeDefault()) {
        let sessionStore = FlashcardSessionStore(cards: cards, startIndex: startIndex)
        let viewModel = FlashcardsViewModel(
            session: sessionStore,
            title: title,
            cards: cards,
            deckID: deckID,
            startEditingOnAppear: startEditing
        )
        _session = StateObject(wrappedValue: sessionStore)
        _viewModel = StateObject(wrappedValue: viewModel)
        _speechManager = ObservedObject(wrappedValue: viewModel.speechManager)
        self.completionService = completionService

        GlobalAudioSessionManager.shared.enterActiveSession()
    }

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                FlashcardsTopBar(
                    width: geo.size.width,
                    index: session.index,
                    total: session.count,
                    sessionRightCount: viewModel.sessionRightCount,
                    sessionWrongCount: viewModel.sessionWrongCount,
                    onClose: {
                        if speechManager.isPlaying {
                            globalAudio.startSession(
                                deckName: viewModel.title,
                                deckID: viewModel.deckID,
                                totalCards: session.count
                            ) {
                                // TODO: integrate RouterStore navigation once available
                            }
                        }
                        dismiss()
                    },
                    onOpenSettings: { viewModel.showSettings = true }
                )

                if let card = session.current {
                    if viewModel.isEditing {
                        ScrollView {
                            CardEditor(
                                draft: binding(\.draft),
                                errorText: binding(\.errorText),
                                familiaritySelection: binding(\.editingFamiliar),
                                llmInstruction: binding(\.llmInstruction),
                                llmError: viewModel.llmError,
                                isGenerating: viewModel.isGeneratingCard,
                                onGenerate: {
                                    if AppConfig.backendURL == nil {
                                        let title = String(localized: "banner.backend.missing.title", locale: locale)
                                        let subtitle = String(localized: "banner.backend.missing.subtitle", locale: locale)
                                        bannerCenter.show(title: title, subtitle: subtitle)
                                        viewModel.llmError = FlashcardCompletionError.backendUnavailable.errorDescription
                                    } else {
                                        Task {
                                            await viewModel.generateCard(using: completionService, locale: locale)
                                        }
                                    }
                                },
                                showsFamiliaritySelector: viewModel.deckID != nil,
                                onDelete: { viewModel.showDeleteConfirm = true }
                            )
                            HStack(spacing: DS.Spacing.md) {
                                Button(String(localized: "action.cancel", locale: locale)) { viewModel.cancelEdit() }
                                    .buttonStyle(DSButton(style: .secondary, size: .full))
                                    .disabled(viewModel.isGeneratingCard)
                                Button(String(localized: "action.save", locale: locale)) {
                                    viewModel.saveEdit(decksStore: decksStore, progressStore: progressStore, locale: locale)
                                }
                                .buttonStyle(DSButton(style: .primary, size: .full))
                                .disabled(viewModel.validationError(locale: locale) != nil || viewModel.isGeneratingCard)
                            }
                        }
                    } else {
                        FlashcardsCardStackView(
                            card: card,
                            mode: mode,
                            session: session,
                            viewModel: viewModel,
                            speechManager: speechManager,
                            bannerCenter: bannerCenter,
                            progressStore: progressStore,
                            availableSize: geo.size,
                            locale: locale,
                            dismiss: dismiss
                        )
                    }
                } else {
                    EmptyState()
                }

                if !viewModel.isEditing {
                    FlashcardsBottomControls(
                        mode: mode,
                        viewModel: viewModel,
                        speechManager: speechManager,
                        progressStore: progressStore
                    )
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, viewModel.isAudioActive ? DS.Spacing.xl : DS.Spacing.lg)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .background(DS.Palette.background)
            .dsAnimation(DS.AnimationToken.subtle, value: viewModel.isAudioActive)
        }
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbar { }
        .onAppear {
            viewModel.handleOnAppear(progressStore: progressStore)
            globalAudio.enterActiveSession()
        }
        .onDisappear {
            globalAudio.exitActiveSession()
        }
        .alert(Text("flashcards.alert.delete"), isPresented: binding(\.showDeleteConfirm)) {
            Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                viewModel.deleteCurrent(decksStore: decksStore)
            }
            Button(String(localized: "action.cancel", locale: locale), role: .cancel) {}
        }
        .sheet(isPresented: binding(\.showSettings)) {
            FlashcardsSettingsSheet(
                ttsStore: speechManager.ttsStore,
                onOpenAudio: { viewModel.showAudioSheet = true },
                onShuffle: {
                    viewModel.shuffleCards(decksStore: decksStore)
                }
            )
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
        .onChange(of: speechManager.currentCardIndex, initial: false) { _, newValue in
            if let v = newValue, v >= 0, v < session.count {
                DSMotion.run(DS.AnimationToken.subtle) {
                    session.setIndex(v)
                    session.resetShowBack()
                }
                globalAudio.updateSessionProgress(currentIndex: v)
            }
        }
        .onChange(of: speechManager.currentFace, initial: false) { _, face in
            switch face {
            case .front?:
                DSMotion.run(DS.AnimationToken.subtle) { session.resetShowBack() }
            case .back?:
                DSMotion.run(DS.AnimationToken.subtle) { session.showBack = true }
            default:
                break
            }
        }
        .onChange(of: session.index, initial: false) { _, _ in
            viewModel.resetComposedBackCache()
        }
        .onChange(of: speechManager.completedCardIndex, initial: false) { _, completedIndex in
            guard let completedIndex else { return }
            guard completedIndex == session.index else {
                speechManager.completedCardIndex = nil
                return
            }
            guard speechManager.isPlaying else {
                speechManager.completedCardIndex = nil
                return
            }
            if mode == .annotate {
                viewModel.adjustProficiency(.unfamiliar, mode: mode, progressStore: progressStore)
            }
            DSMotion.run(DS.AnimationToken.subtle) {
                let reachedEnd = viewModel.advance(mode: mode)
                session.resetShowBack()
                if reachedEnd {
                    viewModel.completeSession(
                        bannerCenter: bannerCenter,
                        locale: locale,
                        dismiss: { dismiss() }
                    )
                }
            }
            speechManager.completedCardIndex = nil
        }
        .onChange(of: speechManager.didCompleteAllCards, initial: false) { _, didComplete in
            guard didComplete else { return }
            speechManager.didCompleteAllCards = false
            viewModel.completeSession(
                bannerCenter: bannerCenter,
                locale: locale,
                dismiss: { dismiss() }
            )
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
