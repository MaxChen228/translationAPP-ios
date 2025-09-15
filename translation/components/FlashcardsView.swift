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
    func flip() { withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showBack.toggle() } }

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
    @EnvironmentObject private var decksStore: FlashcardDecksStore
    @EnvironmentObject private var progressStore: FlashcardProgressStore
    @State private var isEditing: Bool = false
    @State private var draft: Flashcard? = nil
    @State private var errorText: String? = nil
    @State private var showDeleteConfirm: Bool = false
    // Review mode from AppStorage
    @AppStorage("flashcards.reviewMode") private var modeRaw: String = FlashcardsReviewMode.browse.rawValue
    private var mode: FlashcardsReviewMode { get { FlashcardsReviewMode(rawValue: modeRaw) ?? .browse } set { modeRaw = newValue.rawValue } }
    // Swipe annotate state
    @State private var dragX: CGFloat = 0
    @State private var flashDelta: Int? = nil
    @State private var showSettings = false

    init(title: String = "單字卡", cards: [Flashcard] = FlashcardsStore.defaultCards, deckID: UUID? = nil, startIndex: Int = 0) {
        _store = StateObject(wrappedValue: FlashcardsStore(cards: cards, startIndex: startIndex))
        self.title = title
        self.deckID = deckID
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                DSSectionHeader(
                    title: "單字卡",
                    subtitle: "點擊卡片可翻面 (支援 Markdown)",
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
                        CardEditor(draft: $draft, errorText: $errorText, onDelete: { showDeleteConfirm = true })
                        HStack(spacing: DS.Spacing.md) {
                            Button("取消") { cancelEdit() }
                            .buttonStyle(DSSecondaryButton())
                            Button("儲存") { saveEdit() }
                            .buttonStyle(DSPrimaryButton())
                            .disabled(validationError() != nil)
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
                                VariantPhraseView(card.back)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if let note = card.backNote, !note.isEmpty {
                                    NoteText(text: note)
                                }
                            }
                            }
                            .onTapGesture { store.flip() }
                            .offset(x: dragX)
                            .rotationEffect(.degrees(Double(max(-10, min(10, dragX * 0.06)))))

                            if mode == .annotate, let flash = flashDelta {
                                Text(flash > 0 ? "+1" : "-1")
                                    .font(.title2).bold()
                                    .padding(10)
                                    .background(Capsule().fill((flash > 0 ? Color.green : Color.orange).opacity(0.15)))
                                    .overlay(Capsule().stroke((flash > 0 ? Color.green : Color.orange).opacity(0.5), lineWidth: 1))
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
                                    withAnimation(.easeOut(duration: 0.18)) { dragX = dir * 800 }
                                    // Apply annotate if needed, then advance and animate in from opposite side
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                        if mode == .annotate { adjustProficiency(dir > 0 ? +1 : -1) }
                                        store.next()
                                        store.showBack = false
                                        dragX = -dir * 450
                                        withAnimation(.spring(response: 0.42, dampingFraction: 0.85)) { dragX = 0 }
                                    }
                                } else {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { dragX = 0 }
                                }
                            })

                        if mode == .annotate, let deckID = deckID {
                            HStack {
                                let level = progressStore.level(deckID: deckID, cardID: card.id)
                                Text("精熟度 \(level)")
                                    .dsType(DS.Font.caption)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(Capsule().fill(DS.Palette.surface))
                                    .overlay(Capsule().stroke(DS.Palette.border.opacity(0.45), lineWidth: 1))
                                Spacer()
                            }
                        }

                        HStack(spacing: DS.Spacing.md) {
                            Button {
                                store.prev(); store.showBack = false
                            } label: { Label("上一張", systemImage: "chevron.left") }
                            .buttonStyle(DSSecondaryButtonCompact())

                            Button {
                                store.flip()
                            } label: { Label(store.showBack ? "看正面" : "看背面", systemImage: "arrow.2.squarepath") }
                            .buttonStyle(DSPrimaryButton())
                        }
                    }
                } else {
                    EmptyState()
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.xl)
        }
        .background(DS.Palette.background)
        .navigationTitle(title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if store.current != nil {
                    Button(isEditing ? "完成" : "編輯") {
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
                .accessibilityLabel("設定")
            }
        }
        .alert("確定要刪除這張卡片嗎？", isPresented: $showDeleteConfirm) {
            Button("刪除", role: .destructive) { deleteCurrent() }
            Button("取消", role: .cancel) {}
        }
        .sheet(isPresented: $showSettings) {
            FlashcardsSettingsSheet()
                .presentationDetents([.height(220)])
        }
    }
}

private extension FlashcardsView {
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
        if d.front.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return "正面不可空白" }
        if d.back.contains("\n") || d.back.contains("\r") { return "背面需為單行" }
        // Very light bracket check
        let open = d.back.filter { $0 == "(" || $0 == "（" }.count
        let close = d.back.filter { $0 == ")" || $0 == "）" }.count
        if open != close { return "括號需成對" }
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
                Text("編輯卡片").dsType(DS.Font.section)
                TextField("正面（中文短語）", text: Binding(get: { draft?.front ?? "" }, set: { if var d = draft { d.front = $0; draft = d } }))
                    .textFieldStyle(.roundedBorder)
                TextField("正面備註（可留空）", text: Binding(get: { draft?.frontNote ?? "" }, set: { if var d = draft { d.frontNote = $0.isEmpty ? nil : $0; draft = d } }))
                    .textFieldStyle(.roundedBorder)
                TextField("背面（用 (A | B) 單行）", text: Binding(get: { draft?.back ?? "" }, set: { if var d = draft { d.back = $0; draft = d } }))
                    .textFieldStyle(.roundedBorder)
                TextField("背面備註（可留空）", text: Binding(get: { draft?.backNote ?? "" }, set: { if var d = draft { d.backNote = $0.isEmpty ? nil : $0; draft = d } }))
                    .textFieldStyle(.roundedBorder)
                Button("刪除卡片", role: .destructive) { onDelete() }
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
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            flashDelta = delta
        }
        if delta > 0 { Haptics.success() } else { Haptics.warning() }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation(.easeOut(duration: 0.2)) { flashDelta = nil }
        }
    }
}

private struct EmptyState: View {
    var body: some View {
        DSCard {
            VStack(spacing: 8) {
                Image(systemName: "rectangle.on.rectangle.angled").font(.title)
                Text("尚無卡片")
                    .dsType(DS.Font.section)
                    .fontWeight(.semibold)
                Text("稍後可擴充為新增 / 匯入功能。")
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
                front
                    .dsType(DS.Font.body)
            }
            .frame(minHeight: 220)
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
            .opacity(isFlipped ? 0 : 1)

            // Back face (counter-rotated to render readable)
            DSCard(padding: DS.Spacing.lg) {
                back
                    .dsType(DS.Font.body)
            }
            .frame(minHeight: 220)
            .rotation3DEffect(.degrees(isFlipped ? 0 : -180), axis: (x: 0, y: 1, z: 0), perspective: 0.8)
            .opacity(isFlipped ? 1 : 0)
        }
        .animation(.easeInOut(duration: 0.32), value: isFlipped)
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

#Preview {
    NavigationStack { FlashcardsView() }
}
