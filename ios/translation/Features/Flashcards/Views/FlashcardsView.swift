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

    // End of store helpers
}

private enum AnnotateFeedback: Equatable {
    case familiar
    case unfamiliar

    var color: Color {
        switch self {
        case .familiar: return DS.Palette.success
        case .unfamiliar: return DS.Palette.warning
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .familiar: return "flashcards.annotate.familiar"
        case .unfamiliar: return "flashcards.annotate.unfamiliar"
        }
    }
}

struct FlashcardsView: View {
    @StateObject private var store: FlashcardsStore
    private let originalCards: [Flashcard]
    private let title: String
    private let deckID: UUID?
    private let startEditingOnAppear: Bool
    @EnvironmentObject private var decksStore: FlashcardDecksStore
    @EnvironmentObject private var progressStore: FlashcardProgressStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    @StateObject private var speechManager = FlashcardSpeechManager()
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
    @State private var swipePreview: AnnotateFeedback? = nil
    @State private var showSettings = false
    @State private var showAudioSheet = false
    @State private var lastTTSSettings: TTSSettings? = nil
    @State private var currentBackComposed: String = ""
    @State private var currentBackComposedCardID: UUID? = nil
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    private enum ReviewPhase { case allOnce, unfamiliarLoop }
    @State private var phase: ReviewPhase = .allOnce
    @State private var collectedUnfamiliar: Set<UUID> = []
    @State private var showEmptyResetConfirm: Bool = false
    @State private var sessionRightCount: Int = 0
    @State private var sessionWrongCount: Int = 0

    init(title: String = "單字卡", cards: [Flashcard] = FlashcardsStore.defaultCards, deckID: UUID? = nil, startIndex: Int = 0, startEditing: Bool = false) {
        self.originalCards = cards
        _store = StateObject(wrappedValue: FlashcardsStore(cards: cards, startIndex: startIndex))
        self.title = title
        self.deckID = deckID
        self.startEditingOnAppear = startEditing
    }

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                TopBar(
                    width: geo.size.width,
                    index: store.index,
                    total: store.cards.count,
                    onClose: { dismiss() },
                    onOpenSettings: { showSettings = true }
                )

                if let card = store.current {
                    if isEditing {
                        ScrollView {
                            CardEditor(draft: $draft, errorText: $errorText, onDelete: { showDeleteConfirm = true })
                            HStack(spacing: DS.Spacing.md) {
                                Button(String(localized: "action.cancel", locale: locale)) { cancelEdit() }
                                .buttonStyle(DSSecondaryButton())
                                Button(String(localized: "action.save", locale: locale)) { saveEdit() }
                                .buttonStyle(DSPrimaryButton())
                                .disabled(validationError() != nil)
                            }
                        }
                    } else {
                        // 上方顯示左右計數徽章（避免與卡片重疊）
                        if mode == .annotate {
                            let highlight = swipePreview
                            HStack {
                                SideCountBadge(count: sessionWrongCount, color: DS.Palette.warning, filled: highlight == .unfamiliar)
                                Spacer()
                                SideCountBadge(count: sessionRightCount, color: DS.Palette.success, filled: highlight == .familiar)
                            }
                            .padding(.horizontal, DS.Spacing.lg)
                        }

                        ZStack {
                            let preview = (mode == .annotate) ? swipePreview : nil
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
                                            currentBackComposed = s
                                            currentBackComposedCardID = card.id
                                        })
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        if let note = card.backNote, !note.isEmpty {
                                            NoteText(text: note)
                                        }
                                    }
                                } overlay: {
                                    PlaySideButton(style: .outline, diameter: 28) {
                                        if store.showBack {
                                            let text = backTextToSpeak(for: card)
                                            speechManager.speak(text: text, lang: speechManager.settings.backLang, rate: speechManager.settings.rate, speech: speechManager.speechEngine)
                                        } else {
                                            speechManager.speak(text: card.front, lang: speechManager.settings.frontLang, rate: speechManager.settings.rate, speech: speechManager.speechEngine)
                                        }
                                    }
                                }
                            }
                        }
                        .onTapGesture { flipTapped() }
                        .offset(x: dragX)
                        .rotationEffect(.degrees(Double(max(-10, min(10, dragX * 0.06)))))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(300, geo.size.height * 0.62))
                        .gesture(DragGesture(minimumDistance: 20)
                            .onChanged { v in
                                dragX = v.translation.width
                                let threshold: CGFloat = 80
                                updateSwipePreview(for: dragX, threshold: threshold)
                            }
                            .onEnded { v in
                                let t = v.translation.width
                                let threshold: CGFloat = 80
                                if abs(t) > threshold {
                                    let dir: CGFloat = t > 0 ? 1 : -1
                                    let outcome: AnnotateFeedback = dir > 0 ? .familiar : .unfamiliar
                                    DSMotion.run(DS.AnimationToken.tossOut) { dragX = dir * 800 }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                        if mode == .annotate { adjustProficiency(outcome) }
                                        swipePreview = nil
                                        advanceForAnnotate()
                                        store.showBack = false
                                        dragX = -dir * 450
                                        DSMotion.run(DS.AnimationToken.bouncy) { dragX = 0 }
                                    }
                                } else {
                                    DSMotion.run(DS.AnimationToken.bouncy) { dragX = 0 }
                                    swipePreview = nil
                                }
                            })

                        // 移除底部 Unfamiliar 狀態徽章（無意義，避免視覺雜訊）
                        Spacer(minLength: DS.Spacing.md)

                        // 底部角落控制（描邊圓形）：左上一張，右播放/暫停
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
                                systemName: (speechManager.isPlaying && !speechManager.isPaused) ? "pause.fill" : "play.fill",
                                labelKey: (speechManager.isPlaying && !speechManager.isPaused) ? "tts.pause" : "tts.play",
                                action: { ttsToggle() },
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
            .padding(.bottom, (speechManager.isPlaying || speechManager.isPaused) ? DS.Spacing.xl : DS.Spacing.lg)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
            .background(DS.Palette.background)
            .dsAnimation(DS.AnimationToken.subtle, value: (speechManager.isPlaying || speechManager.isPaused))
        }
        // Use custom top bar; hide system navigation chrome
        .navigationTitle("")
        .navigationBarBackButtonHidden(true)
        .toolbar { }
        .onAppear {
            if startEditingOnAppear, !didAutoStartEditing {
                didAutoStartEditing = true
                // Ensure there's a current card then open editor
                if store.current != nil { beginEdit() }
            }
            // 開始新回合
            phase = .allOnce
            collectedUnfamiliar.removeAll()
            sessionRightCount = 0
            sessionWrongCount = 0
            // 僅載入不熟悉的卡片
            applyUnfamiliarFilterOnAppear()
        }
        .alert(Text("flashcards.alert.delete"), isPresented: $showDeleteConfirm) {
            Button(String(localized: "action.delete", locale: locale), role: .destructive) { deleteCurrent() }
            Button(String(localized: "action.cancel", locale: locale), role: .cancel) {}
        }
        .sheet(isPresented: $showSettings) {
            FlashcardsSettingsSheet(ttsStore: speechManager.ttsStore, onOpenAudio: { showAudioSheet = true })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationContentInteraction(.scrolls)
        }
        .sheet(isPresented: $showAudioSheet) {
            FlashcardsAudioSettingsSheet(store: speechManager.ttsStore) { settings in
                startTTS(with: settings)
            }
            .presentationDetents([.height(360)])
        }
        .alert(Text("flashcards.emptyDeckReset.title"), isPresented: $showEmptyResetConfirm) {
            Button(String(localized: "flashcards.emptyDeckReset.cancel", locale: locale), role: .cancel) { dismiss() }
            Button(String(localized: "flashcards.emptyDeckReset.reset", locale: locale), role: .destructive) {
                if let deckID = deckID { progressStore.clearDeck(deckID: deckID) }
                applyUnfamiliarFilterOnAppear()
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
            currentBackComposed = ""
            currentBackComposedCardID = nil
        }
    }
}

private extension FlashcardsView {
    func updateSwipePreview(for offset: CGFloat, threshold: CGFloat) {
        guard mode == .annotate else { swipePreview = nil; return }
        if offset > threshold {
            swipePreview = .familiar
        } else if offset < -threshold {
            swipePreview = .unfamiliar
        } else {
            swipePreview = nil
        }
    }

    var isAudioActive: Bool { speechManager.isPlaying || speechManager.isPaused }
    func applyUnfamiliarFilterOnAppear() {
        guard let deckID = deckID else { return }
        swipePreview = nil
        // 嘗試保留呼叫方傳入的起始卡（若它仍是不熟悉）
        let preferredID: UUID? = (store.index < originalCards.count) ? originalCards[store.index].id : nil
        let filtered: [Flashcard] = originalCards.filter { !progressStore.isFamiliar(deckID: deckID, cardID: $0.id) }
        if filtered.isEmpty { showEmptyResetConfirm = true; return }
        store.cards = filtered
        if let pid = preferredID, let idx = filtered.firstIndex(where: { $0.id == pid }) {
            store.index = idx
        } else {
            store.index = 0
        }
        store.showBack = false
    }
    func beginEdit() {
        guard let card = store.current else { return }
        draft = card
        errorText = nil
        DSMotion.run(DS.AnimationToken.subtle) { isEditing = true }
        store.showBack = false
    }

    func cancelEdit() {
        draft = nil
        errorText = nil
        DSMotion.run(DS.AnimationToken.subtle) { isEditing = false }
    }

    func saveEdit() {
        guard let draftCard = draft else { cancelEdit(); return }
        if let err = validationError() { errorText = err; return }
        // Apply to in-memory list
        if let idx = store.cards.firstIndex(where: { $0.id == draftCard.id }) {
            store.cards[idx] = draftCard
        }
        // Persist to deck store if available
        if let deckID = deckID { decksStore.updateCard(in: deckID, card: draftCard) }
        cancelEdit()
    }

    func validationError() -> String? {
        guard let draft = draft else { return nil }
        if draft.front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return String(localized: "flashcards.validator.frontEmpty", locale: locale) }
        if draft.back.contains("\n") || draft.back.contains("\r") { return String(localized: "flashcards.validator.backSingleLine", locale: locale) }
        // Very light bracket check
        let open = draft.back.filter { $0 == "(" || $0 == "（" }.count
        let close = draft.back.filter { $0 == ")" || $0 == "）" }.count
        if open != close { return String(localized: "flashcards.validator.bracketsMismatch", locale: locale) }
        return nil
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

    func adjustProficiency(_ outcome: AnnotateFeedback) {
        guard mode == .annotate else { return }
        guard let deckID = deckID, let current = store.current else { return }
        switch outcome {
        case .familiar:
            progressStore.markFamiliar(deckID: deckID, cardID: current.id)
            collectedUnfamiliar.remove(current.id)
            sessionRightCount &+= 1
            Haptics.success()
        case .unfamiliar:
            progressStore.markUnfamiliar(deckID: deckID, cardID: current.id)
            if phase == .allOnce { collectedUnfamiliar.insert(current.id) }
            sessionWrongCount &+= 1
            Haptics.warning()
        }
    }

    // 非循環推進：用於標注模式，末張代表回合結束
    func advanceForAnnotate() {
        guard mode == .annotate else { store.next(); return }
        guard !store.cards.isEmpty else { return }
        if store.index < store.cards.count - 1 {
            store.index += 1
        } else {
            handleEndOfRound()
        }
    }

    func handleEndOfRound() {
        // 簡化：每輪結束即返回牌組頁
        completeSession()
    }

    func startSecondPhase(with ids: [UUID]) {
        phase = .unfamiliarLoop
        // 以當前卡片（可能經過編輯）為基礎保序過濾
        var list: [Flashcard] = []
        let idset = Set(ids)
        for c in store.cards { if idset.contains(c.id) { list.append(c) } }
        if list.isEmpty { completeSession(); return }
        store.cards = list
        store.index = 0
        store.showBack = false
        if isAudioActive, let s = lastTTSSettings { speechManager.stop(); startTTS(with: s) }
        bannerCenter.show(title: String(localized: "flashcards.round.completed", locale: locale))
    }

    func restartUnfamiliarRound(with list: [Flashcard]) {
        store.cards = list
        store.index = 0
        store.showBack = false
        if isAudioActive, let s = lastTTSSettings { speechManager.stop(); startTTS(with: s) }
        bannerCenter.show(title: String(localized: "flashcards.round.completed", locale: locale))
    }

    func completeSession() {
        bannerCenter.show(title: String(localized: "flashcards.session.completed", locale: locale))
        // 稍微延遲再返回，確保橫幅有時間顯示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { dismiss() }
    }

    func goToPreviousAnimated(restartAudio: Bool = false) {
        swipePreview = nil
        guard !store.cards.isEmpty else { return }
        let dir: CGFloat = 1 // toss right then bring previous from left
        DSMotion.run(DS.AnimationToken.tossOut) { dragX = dir * 800 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            store.prev(); store.showBack = false
            dragX = -dir * 450
            DSMotion.run(DS.AnimationToken.bouncy) { dragX = 0 }
            if restartAudio {
                let s = lastTTSSettings ?? speechManager.settings
                speechManager.stop()
                startTTS(with: s)
            }
        }
    }

    func prevButtonTapped() {
        goToPreviousAnimated(restartAudio: isAudioActive)
    }

    func flipTapped() {
        store.flip()
        guard let card = store.current, (speechManager.isPlaying || speechManager.isPaused) else { return }
        // Interject via instant speaker without killing the continuous queue (pause → speak → buffered resume)
        if store.showBack {
            let text = backTextToSpeak(for: card)
            speechManager.speak(text: text, lang: speechManager.settings.backLang, rate: speechManager.settings.rate, speech: speechManager.speechEngine)
        } else {
            speechManager.speak(text: card.front, lang: speechManager.settings.frontLang, rate: speechManager.settings.rate, speech: speechManager.speechEngine)
        }
    }

    // MARK: - TTS
    func startTTS(with settings: TTSSettings) {
        let queue = PlaybackBuilder.buildQueue(cards: store.cards, startIndex: store.index, settings: settings)
        speechManager.play(queue: queue)
        lastTTSSettings = settings
    }

    func speakOne(text: String, lang: String) {
        let rate = speechManager.settings.rate
        let item = SpeechItem(text: text, langCode: lang, rate: rate, preDelay: 0, postDelay: 0, cardIndex: store.index, face: store.showBack ? .back : .front)
        // Legacy one-shot via continuous engine is no longer used for instant playback.
        // Keep method for compatibility if needed elsewhere.
        speechManager.play(queue: [item])
        lastTTSSettings = speechManager.settings
    }

    func ttsToggle() {
        if speechManager.isPlaying && !speechManager.isPaused { speechManager.pause(); return }
        if speechManager.isPlaying && speechManager.isPaused { speechManager.resume(); return }
        // Not playing: start with last settings or default
        startTTS(with: lastTTSSettings ?? speechManager.settings)
    }

    func ttsNextCard() {
        guard !store.cards.isEmpty else { return }
        store.next()
        store.showBack = false
        if let s = lastTTSSettings {
            speechManager.stop()
            startTTS(with: s)
        }
    }

    func ttsPrevCard() {
        guard !store.cards.isEmpty else { return }
        store.prev()
        store.showBack = false
        if let s = lastTTSSettings {
            speechManager.stop()
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

private extension FlashcardsView {
    func backImmediateText(for card: Flashcard) -> String {
        let lines = PlaybackBuilder.buildBackLines(card.back, fill: speechManager.settings.variantFill)
        return lines.first ?? card.back
    }
    func backTextToSpeak(for card: Flashcard) -> String {
        if let id = currentBackComposedCardID, id == card.id, !currentBackComposed.isEmpty {
            return currentBackComposed
        }
        return backImmediateText(for: card)
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
