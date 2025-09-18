import SwiftUI

struct Flashcard: Identifiable, Codable, Equatable {
    let id: UUID
    var front: String
    var frontNote: String?
    var back: String
    var backNote: String?

    init(id: UUID = UUID(), front: String, back: String, frontNote: String? = nil, backNote: String? = nil) {
        self.id = id
        self.front = front
        self.frontNote = frontNote
        self.back = back
        self.backNote = backNote
    }
}

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
}

struct FlashcardsView: View {
    @StateObject private var store: FlashcardsStore
    private let title: String
    private let deckID: UUID?
    private let startEditingOnAppear: Bool
    @EnvironmentObject private var decksStore: FlashcardDecksStore
    @EnvironmentObject private var progressStore: FlashcardProgressStore
    @StateObject private var speech = SpeechEngine()
    @StateObject private var ttsStore = TTSSettingsStore()
    @State private var isEditing: Bool = false
    @State private var draft: Flashcard? = nil
    @State private var errorText: String? = nil
    @State private var showDeleteConfirm: Bool = false
    @State private var didAutoStartEditing: Bool = false
    // Review mode from AppStorage
    @AppStorage("flashcards.reviewMode") private var modeRaw: String = FlashcardsReviewMode.browse.rawValue
    private var mode: FlashcardsReviewMode { get { FlashcardsReviewMode(rawValue: modeRaw) ?? .browse } set { modeRaw = newValue.rawValue } }
    // Swipe annotate state
    @State private var dragX: CGFloat = 0
    @State private var flashDelta: Int? = nil
    @State private var showSettings = false
    @State private var showAudioSheet = false
    @State private var lastTTSSettings: TTSSettings? = nil
    @State private var currentBackComposed: String = ""
    @Environment(\.locale) private var locale

    init(title: String = "單字卡", cards: [Flashcard] = FlashcardsStore.defaultCards, deckID: UUID? = nil, startIndex: Int = 0, startEditing: Bool = false) {
        _store = StateObject(wrappedValue: FlashcardsStore(cards: cards, startIndex: startIndex))
        self.title = title
        self.deckID = deckID
        self.startEditingOnAppear = startEditing
    }

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                DSSectionHeader(
                    title: String(localized: "flashcards.title", locale: locale),
                    subtitle: String(localized: "flashcards.subtitle", locale: locale),
                    accentUnderline: true,
                    accentMatchTitle: true
                )

                // 進度指示（模式改到設定）
                if !store.cards.isEmpty {
                    HStack {
                        Spacer()
                        Text("\(store.index + 1) / \(store.cards.count)")
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let card = store.current {
                    if isEditing {
                        ScrollView {
                            CardEditor(draft: $draft, errorText: $errorText, onDelete: { showDeleteConfirm = true })
                            HStack(spacing: DS.Spacing.md) {
                                Button("取消") { cancelEdit() }
                                .buttonStyle(DSSecondaryButton())
                                Button("儲存") { saveEdit() }
                                .buttonStyle(DSPrimaryButton())
                                .disabled(validationError() != nil)
                            }
                        }
                    } else {
                        ZStack {
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
                                    VariantBracketComposerView(card.back, onComposedChange: { s in currentBackComposed = s })
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    if let note = card.backNote, !note.isEmpty {
                                        NoteText(text: note)
                                    }
                                }
                            }
                            .onTapGesture { flipTapped() }
                            .offset(x: dragX)
                            .rotationEffect(.degrees(Double(max(-10, min(10, dragX * 0.06)))))
                            .overlay(alignment: .bottomTrailing) {
                                PlaySideButton(style: .outline, diameter: 28) {
                                    if store.showBack {
                                        speakOne(text: currentBackComposed.isEmpty ? card.back : currentBackComposed, lang: ttsStore.settings.backLang)
                                    } else {
                                        speakOne(text: card.front, lang: ttsStore.settings.frontLang)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 260)
                            .frame(maxHeight: .infinity)
                            if mode == .annotate, let flash = flashDelta {
                                Text(flash > 0 ? "+1" : "-1")
                                    .font(.title2).bold()
                                    .padding(10)
                                    .background(Capsule().fill((flash > 0 ? Color.green : Color.orange).opacity(0.15)))
                                    .overlay(Capsule().stroke((flash > 0 ? Color.green : Color.orange).opacity(0.5), lineWidth: DS.BorderWidth.regular))
                            }
                        }
                        .gesture(DragGesture(minimumDistance: 20)
                            .onChanged { v in dragX = v.translation.width }
                            .onEnded { v in
                                let t = v.translation.width
                                let threshold: CGFloat = 80
                                if abs(t) > threshold {
                                    let dir: CGFloat = t > 0 ? 1 : -1
                                    // Toss out
                                    withAnimation(DS.AnimationToken.tossOut) { dragX = dir * 800 }
                                    // Apply annotate if needed, then advance and animate in from opposite side
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                        if mode == .annotate { adjustProficiency(dir > 0 ? +1 : -1) }
                                        store.next()
                                        store.showBack = false
                                        dragX = -dir * 450
                                        withAnimation(DS.AnimationToken.bouncy) { dragX = 0 }
                                    }
                                } else {
                                    withAnimation(DS.AnimationToken.bouncy) { dragX = 0 }
                                }
                            })

                        if mode == .annotate, let deckID = deckID {
                            HStack {
                                let level = progressStore.level(deckID: deckID, cardID: card.id)
                                Text(String(format: String(localized: "flashcards.level", locale: locale), level))
                                    .dsType(DS.Font.caption)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(Capsule().fill(DS.Palette.surface))
                                    .overlay(Capsule().stroke(DS.Palette.border.opacity(0.45), lineWidth: DS.BorderWidth.regular))
                                Spacer()
                            }
                        }
                        Spacer(minLength: DS.Spacing.md)

                        // 底部控制列：在播音模式也顯示（由 safeAreaInset 自動把內容往上推）
                            HStack(spacing: DS.Spacing.md) {
                            Button { prevButtonTapped() } label: { Label { Text("flashcards.prev") } icon: { Image(systemName: "chevron.left") } }
                                .buttonStyle(DSSecondaryButtonCompact())

                            Button { flipTapped() } label: { Label { Text(store.showBack ? LocalizedStringKey("flashcards.showFront") : LocalizedStringKey("flashcards.showBack")) } icon: { Image(systemName: "arrow.2.squarepath") } }
                            .buttonStyle(DSPrimaryButton())
                            }
                    }
                } else {
                    EmptyState()
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, (speech.isPlaying || speech.isPaused) ? DS.Spacing.xl : DS.Spacing.lg)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .background(DS.Palette.background)
            .animation(DS.AnimationToken.subtle, value: (speech.isPlaying || speech.isPaused))
        }
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.current != nil {
                    Button(isEditing ? String(localized: "action.done", locale: locale) : String(localized: "action.edit", locale: locale)) {
                        if isEditing { saveEdit() } else { beginEdit() }
                    }
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(Text("nav.settings"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAudioSheet = true
                } label: {
                    Image(systemName: "speaker.wave.2")
                }
                .accessibilityLabel(Text("flashcards.audioSettings"))
            }
        }
        .onAppear {
            if startEditingOnAppear, !didAutoStartEditing {
                didAutoStartEditing = true
                // Ensure there's a current card then open editor
                if store.current != nil { beginEdit() }
            }
        }
        .alert(Text("flashcards.alert.delete"), isPresented: $showDeleteConfirm) {
            Button(String(localized: "action.delete", locale: locale), role: .destructive) { deleteCurrent() }
            Button(String(localized: "action.cancel", locale: locale), role: .cancel) {}
        }
        .sheet(isPresented: $showSettings) {
            FlashcardsSettingsSheet()
                .presentationDetents([.height(220)])
        }
        .sheet(isPresented: $showAudioSheet) {
            FlashcardsAudioSettingsSheet(store: ttsStore) { settings in
                startTTS(with: settings)
            }
            .presentationDetents([.height(360)])
        }
        .safeAreaInset(edge: .bottom) {
            if speech.isPlaying || speech.isPaused {
                AudioMiniPlayerView(
                    title: title,
                    index: store.index + 1,
                    total: max(1, store.cards.count),
                    isPlaying: speech.isPlaying,
                    isPaused: speech.isPaused,
                    progress: (speech.totalItems > 0 ? Double(speech.currentIndex) / Double(max(1, speech.totalItems)) : 0),
                    level: speech.level,
                    onPrev: { ttsPrevCard() },
                    onToggle: { ttsToggle() },
                    onNext: { ttsNextCard() },
                    onStop: { speech.stop() }
                )
            }
        }
        .onChange(of: speech.currentCardIndex, initial: false) { _, newValue in
            if let v = newValue, v >= 0, v < store.cards.count {
                withAnimation(DS.AnimationToken.subtle) {
                    store.index = v
                    store.showBack = false
                }
            }
        }
        .onChange(of: speech.currentFace, initial: false) { _, face in
            switch face {
            case .front?:
                withAnimation(DS.AnimationToken.subtle) { store.showBack = false }
            case .back?:
                withAnimation(DS.AnimationToken.subtle) { store.showBack = true }
            default:
                break
            }
        }
    }
}

private extension FlashcardsView {
    var isAudioActive: Bool { speech.isPlaying || speech.isPaused }
    func beginEdit() {
        guard let card = store.current else { return }
        draft = card
        errorText = nil
        withAnimation { isEditing = true }
        store.showBack = false
    }

    func cancelEdit() {
        draft = nil
        errorText = nil
        withAnimation { isEditing = false }
    }

    func saveEdit() {
        guard var d = draft else { cancelEdit(); return }
        if let err = validationError() { errorText = err; return }
        // Apply to in-memory list
        if let idx = store.cards.firstIndex(where: { $0.id == d.id }) {
            store.cards[idx] = d
        }
        // Persist to deck store if available
        if let deckID = deckID { decksStore.updateCard(in: deckID, card: d) }
        cancelEdit()
    }

    func validationError() -> String? {
        guard let d = draft else { return nil }
        if d.front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return String(localized: "flashcards.validator.frontEmpty", locale: locale) }
        if d.back.contains("\n") || d.back.contains("\r") { return String(localized: "flashcards.validator.backSingleLine", locale: locale) }
        // Very light bracket check
        let open = d.back.filter { $0 == "(" || $0 == "（" }.count
        let close = d.back.filter { $0 == ")" || $0 == "）" }.count
        if open != close { return String(localized: "flashcards.validator.bracketsMismatch", locale: locale) }
        return nil
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
                if let errorText { Text(errorText).foregroundStyle(.red).font(.caption) }
            }
        }
    }
}

private extension FlashcardsView {
    func deleteCurrent() {
        guard let current = draft ?? store.current else { return }
        // Remove from in-memory list
        if let idx = store.cards.firstIndex(where: { $0.id == current.id }) {
            store.cards.remove(at: idx)
            if store.index >= store.cards.count { store.index = max(0, store.cards.count - 1) }
        }
        // Persist
        if let deckID = deckID { decksStore.deleteCard(from: deckID, cardID: current.id) }
        // Exit edit mode
        cancelEdit()
    }

    func adjustProficiency(_ delta: Int) {
        guard mode == .annotate else { return }
        guard let deckID = deckID, let current = store.current else { return }
        let _ = progressStore.adjust(deckID: deckID, cardID: current.id, delta: delta)
        withAnimation(DS.AnimationToken.snappy) {
            flashDelta = delta
        }
        if delta > 0 { Haptics.success() } else { Haptics.warning() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(DS.AnimationToken.subtle) { flashDelta = nil }
        }
    }

    func goToPreviousAnimated(restartAudio: Bool = false) {
        guard !store.cards.isEmpty else { return }
        let dir: CGFloat = 1 // toss right then bring previous from left
        withAnimation(DS.AnimationToken.tossOut) { dragX = dir * 800 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            store.prev(); store.showBack = false
            dragX = -dir * 450
            withAnimation(DS.AnimationToken.bouncy) { dragX = 0 }
            if restartAudio {
                let s = lastTTSSettings ?? ttsStore.settings
                speech.stop()
                startTTS(with: s)
            }
        }
    }

    func prevButtonTapped() {
        goToPreviousAnimated(restartAudio: isAudioActive)
    }

    func flipTapped() {
        store.flip()
        guard let card = store.current, isAudioActive else { return }
        // Stop current queue and immediately read the face now shown
        speech.stop()
        if store.showBack {
            let text = currentBackComposed.isEmpty ? card.back : currentBackComposed
            speakOne(text: text, lang: ttsStore.settings.backLang)
        } else {
            speakOne(text: card.front, lang: ttsStore.settings.frontLang)
        }
    }

    // MARK: - TTS
    func startTTS(with settings: TTSSettings) {
        let queue = PlaybackBuilder.buildQueue(cards: store.cards, startIndex: store.index, settings: settings)
        speech.play(queue: queue)
        lastTTSSettings = settings
    }

    func speakOne(text: String, lang: String) {
        let rate = ttsStore.settings.rate
        let item = SpeechItem(text: text, langCode: lang, rate: rate, preDelay: 0, postDelay: 0, cardIndex: store.index, face: store.showBack ? .back : .front)
        speech.play(queue: [item])
        lastTTSSettings = ttsStore.settings
    }

    func ttsToggle() {
        if speech.isPlaying && !speech.isPaused { speech.pause(); return }
        if speech.isPlaying && speech.isPaused { speech.resume(); return }
        // Not playing: start with last settings or default
        startTTS(with: lastTTSSettings ?? ttsStore.settings)
    }

    func ttsNextCard() {
        guard !store.cards.isEmpty else { return }
        store.next()
        store.showBack = false
        if let s = lastTTSSettings {
            speech.stop()
            startTTS(with: s)
        }
    }

    func ttsPrevCard() {
        guard !store.cards.isEmpty else { return }
        store.prev()
        store.showBack = false
        if let s = lastTTSSettings {
            speech.stop()
            startTTS(with: s)
        }
    }

    // Sync UI to speech progress
    nonisolated func _noop() {}
}

extension FlashcardsView {
    @MainActor
    func bindSpeechSync() -> some View { EmptyView() }
}

private struct PlaySideButton: View {
    enum Style { case filled, outline }
    var style: Style = .filled
    var diameter: CGFloat = 28
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(style == .filled ? Color.white : DS.Palette.primary)
        }
        .buttonStyle(style == .filled ? AnyButtonStyle(DSPrimaryCircleButton(diameter: diameter)) : AnyButtonStyle(DSOutlineCircleButton(diameter: diameter)))
        .padding(6)
    }
}

// Helper to erase generic ButtonStyle type for conditional usage
private struct AnyButtonStyle: ButtonStyle {
    private let _makeBody: (Configuration) -> AnyView
    init<S: ButtonStyle>(_ style: S) { _makeBody = { AnyView(style.makeBody(configuration: $0)) } }
    func makeBody(configuration: Configuration) -> some View { _makeBody(configuration) }
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

private struct FlipCard<Front: View, Back: View>: View {
    var isFlipped: Bool
    let front: Front
    let back: Back

    init(isFlipped: Bool, @ViewBuilder front: () -> Front, @ViewBuilder back: () -> Back) {
        self.isFlipped = isFlipped
        self.front = front()
        self.back = back()
    }

    var body: some View {
        ZStack {
            // Front face
            DSCard(padding: DS.Spacing.lg) {
                // Vertically center content while keeping leading alignment
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    front
                        .dsType(DS.Font.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minHeight: 220)
            .frame(maxHeight: .infinity)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
            .opacity(isFlipped ? 0 : 1)

            // Back face (counter-rotated to render readable)
            DSCard(padding: DS.Spacing.lg) {
                // Vertically center content while keeping leading alignment
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    back
                        .dsType(DS.Font.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minHeight: 220)
            .frame(maxHeight: .infinity)
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
