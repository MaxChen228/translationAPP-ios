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

    static var defaultCards: [Flashcard] = [
        Flashcard(
            front: "# ameliorate\n\n- verb\n- to make something better; improve\n\n**Example**: *We need to ameliorate the working conditions.*",
            back: "**中文**：改善、改進\n\n- 近義：improve, enhance\n- 反義：worsen\n\n> 記憶：a- (to) + melior (better)",
            frontNote: nil,
            backNote: "備註：正式語氣，日常可用 improve"
        ),
        Flashcard(
            front: "# ubiquitous\n\n- adjective\n- present, appearing, or found everywhere\n\n`Wi‑Fi` is ubiquitous in modern cities.",
            back: "**中文**：普遍存在的、無所不在的\n\n- 例：智慧型手機已經無所不在\n- 片語：ubiquitous presence",
            frontNote: nil,
            backNote: "備註：口語亦可用 everywhere/commonly seen"
        ),
        Flashcard(
            front: "# succinct\n\n- adjective\n- briefly and clearly expressed\n\n**Synonyms**: concise, terse",
            back: "**中文**：簡潔的、言簡意賅的\n\n- 用法：a succinct summary\n- 小技巧：suc- (sub) + cinct (gird) → ‘束起來’ → 簡明",
            frontNote: nil,
            backNote: nil
        )
    ]

    // End of store helpers
}

struct FlashcardsView: View {
    @StateObject private var store: FlashcardsStore
    @StateObject private var viewModel: FlashcardsViewModel
    @EnvironmentObject private var decksStore: FlashcardDecksStore
    @EnvironmentObject private var progressStore: FlashcardProgressStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    @AppStorage("flashcards.reviewMode") private var modeRaw: String = FlashcardsReviewMode.browse.rawValue
    private var mode: FlashcardsReviewMode { get { FlashcardsReviewMode(rawValue: modeRaw) ?? .browse } set { modeRaw = newValue.rawValue } }
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    init(title: String = "單字卡", cards: [Flashcard] = FlashcardsStore.defaultCards, deckID: UUID? = nil, startIndex: Int = 0, startEditing: Bool = false) {
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
    }

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                TopBar(
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
                                ClassificationCard(label: preview.label, color: preview.color)
                                    .dsAnimation(DS.AnimationToken.subtle, value: preview)
                            } else {
                                FlipCard(isFlipped: store.showBack) {
                                    VStack(alignment: .leading, spacing: 10) {
                                        MarkdownText(card.front)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        if let note = card.frontNote, !note.isEmpty {
                                            NoteText(text: note)
                                        }
                                    }
                                } back: {
                                    VStack(alignment: .leading, spacing: 10) {
                                        VariantBracketComposerView(card.back, onComposedChange: { s in
                                            viewModel.recordBackComposition(for: card.id, text: s)
                                        })
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        if let note = card.backNote, !note.isEmpty {
                                            NoteText(text: note)
                                        }
                                    }
                                } overlay: {
                                    PlaySideButton(style: .outline, diameter: 28) {
                                        let manager = viewModel.speechManager
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
                        .onTapGesture { flipTapped() }
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
                                action: { prevButtonTapped() },
                                shape: .circle,
                                style: .outline,
                                size: 44
                            )
                            Spacer()
                            DSQuickActionIconButton(
                                systemName: (viewModel.speechManager.isPlaying && !viewModel.speechManager.isPaused) ? "pause.fill" : "play.fill",
                                labelKey: (viewModel.speechManager.isPlaying && !viewModel.speechManager.isPaused) ? "tts.pause" : "tts.play",
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
            FlashcardsSettingsSheet(ttsStore: viewModel.speechManager.ttsStore, onOpenAudio: { viewModel.showAudioSheet = true })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: binding(\.showAudioSheet)) {
            FlashcardsAudioSettingsSheet(store: viewModel.speechManager.ttsStore) { settings in
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
        .onChange(of: viewModel.speechManager.currentCardIndex, initial: false) { _, newValue in
            if let v = newValue, v >= 0, v < store.cards.count {
                DSMotion.run(DS.AnimationToken.subtle) {
                    store.index = v
                    store.showBack = false
                }
            }
        }
        .onChange(of: viewModel.speechManager.currentFace, initial: false) { _, face in
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

    func prevButtonTapped() {
        goToPreviousAnimated(restartAudio: viewModel.isAudioActive)
    }

    func goToPreviousAnimated(restartAudio: Bool) {
        viewModel.swipePreview = nil
        guard !store.cards.isEmpty else { return }
        let dir: CGFloat = 1
        DSMotion.run(DS.AnimationToken.tossOut) { viewModel.dragX = dir * 800 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            store.prev()
            store.showBack = false
            viewModel.dragX = -dir * 450
            DSMotion.run(DS.AnimationToken.bouncy) { viewModel.dragX = 0 }
            if restartAudio {
                let settings = viewModel.lastTTSSettings ?? viewModel.speechManager.settings
                viewModel.speechManager.stop()
                viewModel.startTTS(with: settings)
            }
        }
    }

    func flipTapped() {
        store.flip()
        guard let card = store.current, viewModel.isAudioActive else { return }
        let manager = viewModel.speechManager
        if store.showBack {
            let text = viewModel.backTextToSpeak(for: card)
            viewModel.speak(text: text, lang: manager.settings.backLang)
        } else {
            viewModel.speak(text: card.front, lang: manager.settings.frontLang)
        }
    }
}

// 側邊計數徽章（圓角膠囊，顯示數字）
private struct SideCountBadge: View {
    let count: Int
    let color: Color
    var filled: Bool = false
    var body: some View {
        Text("\(count)")
            .font(.headline).bold()
            .foregroundStyle(filled ? Color.white : .primary)
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule().fill(filled ? color : color.opacity(0.12))
            )
            .overlay(
                Capsule().stroke(color.opacity(filled ? 0.0 : 0.6), lineWidth: DS.BorderWidth.regular)
            )
    }
}

private struct CardEditor: View {
    @Binding var draft: Flashcard?
    @Binding var errorText: String?
    let onDelete: () -> Void
    var body: some View {
        DSCard(padding: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: 12) {
                Text("flashcards.editor.title").dsType(DS.Font.section)
                TextField(LocalizedStringKey("flashcards.editor.front"), text: Binding(get: { draft?.front ?? "" }, set: { if var d = draft { d.front = $0; draft = d } }))
                    .textFieldStyle(.roundedBorder)
                TextField(LocalizedStringKey("flashcards.editor.frontNote"), text: Binding(get: { draft?.frontNote ?? "" }, set: { if var d = draft { d.frontNote = $0.isEmpty ? nil : $0; draft = d } }))
                    .textFieldStyle(.roundedBorder)
                TextField(LocalizedStringKey("flashcards.editor.back"), text: Binding(get: { draft?.back ?? "" }, set: { if var d = draft { d.back = $0; draft = d } }))
                    .textFieldStyle(.roundedBorder)
                TextField(LocalizedStringKey("flashcards.editor.backNote"), text: Binding(get: { draft?.backNote ?? "" }, set: { if var d = draft { d.backNote = $0.isEmpty ? nil : $0; draft = d } }))
                    .textFieldStyle(.roundedBorder)
                Button(role: .destructive) { onDelete() } label: { Text("flashcards.editor.delete") }
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let errorText { Text(errorText).foregroundStyle(DS.Palette.danger).font(.caption) }
            }
        }
    }
}

private struct PlaySideButton: View {
    enum Style { case filled, outline }
    var style: Style = .filled
    var diameter: CGFloat = 28
    var action: () -> Void
    var body: some View {
        DSQuickActionIconButton(
            systemName: "speaker.wave.2.fill",
            labelKey: "tts.play",
            action: action,
            shape: .circle,
            style: style == .filled ? .filled : .outline,
            size: diameter
        )
        .padding(6)
    }
}

private struct ClassificationCard: View {
    var label: LocalizedStringKey
    var color: Color
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(color, lineWidth: 4)
            Text(label)
                .font(.title).bold()
                .foregroundStyle(color)
        }
        // Animation keyed by layout changes; no explicit value needed here
    }
}

private struct TopBar: View {
    let width: CGFloat
    let index: Int
    let total: Int
    let onClose: () -> Void
    let onOpenSettings: () -> Void
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                DSQuickActionIconButton(systemName: "xmark", labelKey: "action.cancel", action: onClose, style: .outline)
                Spacer()
                Text("\(min(max(1, index + 1), max(1, total))) / \(max(1, total))")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Spacer()
                DSQuickActionIconButton(systemName: "gearshape", labelKey: "nav.settings", action: onOpenSettings, style: .outline)
            }
            // Slim progress bar
            let prog = (total <= 0 ? 0.0 : Double(index + 1) / Double(max(1, total)))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(DS.Palette.border.opacity(0.25))
                    .frame(height: 4)
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(DS.Palette.primary)
                    .frame(width: max(0, (width - DS.Spacing.lg * 2) * prog), height: 4)
            }
        }
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

private struct FlipCard<Front: View, Back: View, Overlay: View>: View {
    var isFlipped: Bool
    let front: Front
    let back: Back
    let overlay: () -> Overlay

    init(isFlipped: Bool,
         @ViewBuilder front: () -> Front,
         @ViewBuilder back: () -> Back,
         @ViewBuilder overlay: @escaping () -> Overlay) {
        self.isFlipped = isFlipped
        self.front = front()
        self.back = back()
        self.overlay = overlay
    }

    @ViewBuilder
    private func faceCard<Content: View>(_ content: Content) -> some View {
        DSCard(padding: DS.Spacing.lg) {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                content
                    .dsType(DS.Font.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minHeight: 220)
        .frame(maxHeight: .infinity)
        .overlay(alignment: .bottomTrailing) { overlay() }
    }

    var body: some View {
        ZStack {
            // Front face
            faceCard(front)
                .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
                .opacity(isFlipped ? 0 : 1)

            // Back face (counter-rotated to render readable)
            faceCard(back)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
                .opacity(isFlipped ? 1 : 0)
        }
        .dsAnimation(DS.AnimationToken.flip, value: isFlipped)
    }
}

private struct MarkdownText: View {
    let text: String
    init(_ text: String) { self.text = text }

    private func preprocess(_ md: String) -> String {
        // Minimal block-level handling so lists/headings render nicely in Text
        // - Replace leading Markdown list markers with bullets
        // - Strip heading markers but keep line breaks
        return md.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            let s = String(line)
            if s.trimmingCharacters(in: .whitespaces).hasPrefix("- ") || s.trimmingCharacters(in: .whitespaces).hasPrefix("* ") {
                return "• " + s.trimmingCharacters(in: .whitespaces).dropFirst(2)
            }
            if s.trimmingCharacters(in: .whitespaces).hasPrefix("#") {
                // Remove leading #'s and a single space if present
                let trimmed = s.trimmingCharacters(in: .whitespaces)
                let dropped = trimmed.drop(while: { $0 == "#" || $0 == " " })
                return String(dropped)
            }
            return s
        }.joined(separator: "\n")
    }

    var body: some View {
        let processed = preprocess(text)
        Group {
            if let attr = try? AttributedString(
                markdown: processed,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )
            ) {
                Text(attr)
            } else {
                Text(processed)
            }
        }
        .foregroundStyle(.primary)
        .textSelection(.enabled)
    }
}

private struct NoteText: View {
    let text: String
    var body: some View {
        Text(text)
            .dsType(DS.Font.caption)
            .foregroundStyle(.secondary)
    }
}

#Preview { NavigationStack { FlashcardsView() } }
