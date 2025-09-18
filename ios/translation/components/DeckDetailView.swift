import SwiftUI

struct DeckDetailView: View {
    let deckID: UUID
    @EnvironmentObject private var decksStore: FlashcardDecksStore
    @EnvironmentObject private var progressStore: FlashcardProgressStore
    @State private var navigateToNewEditor: Bool = false
    @State private var newCardStartIndex: Int = 0
    @Environment(\.locale) private var locale

    private var deck: PersistedFlashcardDeck? {
        decksStore.decks.first(where: { $0.id == deckID })
    }

    // Counters based on progress levels
    private var counts: (new: Int, learning: Int, mastered: Int) {
        guard let d = deck else { return (0,0,0) }
        let threshold = 3
        var new = 0, learning = 0, mastered = 0
        for c in d.cards {
            let lvl = max(0, progressStore.level(deckID: d.id, cardID: c.id))
            if lvl == 0 { new += 1 }
            else if lvl >= threshold { mastered += 1 }
            else { learning += 1 }
        }
        return (new, learning, mastered)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if let d = deck {
                    DSSectionHeader(titleText: Text(d.name), subtitleText: Text("deck.detail.subtitle"), accentUnderline: true)

                    // 上：高質感圓環摘要（壓縮且資訊清晰）
                    DeckSummaryRings(new: counts.new, learning: counts.learning, mastered: counts.mastered)

                    // 中：行動區（開始複習 → 直接進入整副卡片）
                    NavigationLink {
                        FlashcardsView(title: d.name, cards: d.cards, deckID: d.id)
                    } label: {
                        Text("deck.action.startReview")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DSPrimaryButton())

                    // 隱藏導頁器：新增卡片後直接進入編輯
                    NavigationLink(isActive: $navigateToNewEditor) {
                        FlashcardsView(title: d.name, cards: d.cards, deckID: d.id, startIndex: newCardStartIndex, startEditing: true)
                    } label: { EmptyView() }

                    // 下：卡片簡略列表（新增改為懸浮按鈕，避免擁擠）
                    Text("deck.words.title").dsType(DS.Font.section)
                    VStack(spacing: 10) {
                        ForEach(d.cards) { card in
                            let idx = d.cards.firstIndex(where: { $0.id == card.id }) ?? 0
                            NavigationLink {
                                FlashcardsView(title: d.name, cards: d.cards, deckID: d.id, startIndex: idx)
                            } label: {
                                CardPreviewRow(card: card)
                            }
                            .buttonStyle(DSCardLinkStyle())
                        }
                    }
                } else {
                    Text(String(localized: "deck.notFound", locale: locale)).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        // 右下懸浮新增按鈕（FAB）：降低視覺干擾且隨時可用
        .safeAreaInset(edge: .bottom, alignment: .trailing) {
            if deck != nil {
                HStack { Spacer() }
                    .overlay(alignment: .trailing) {
                        Button { addNewCardAndEdit() } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .buttonStyle(DSPrimaryCircleButton(diameter: 44))
                        .padding(.trailing, DS.Spacing.lg)
                        .padding(.bottom, DS.Spacing.lg)
                        .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 6)
                        .accessibilityLabel(Text("deck.action.addCard"))
                    }
            }
        }
        .navigationTitle(Text("nav.deck"))
    }
}

// 高質感圓環摘要：以 3 欄圓環 + 標題呈現，節省高度且資訊清晰
private struct DeckSummaryRings: View {
    let new: Int
    let learning: Int
    let mastered: Int
    var total: Int { max(1, new + learning + mastered) }
    @Environment(\.locale) private var locale
    var body: some View {
        DSCard {
            HStack(spacing: 0) {
                SummaryRing(titleKey: "deck.summary.new", count: new, total: total, color: DS.Brand.scheme.provence)
                Divider().frame(height: 42).opacity(0.15)
                SummaryRing(titleKey: "deck.summary.learning", count: learning, total: total, color: DS.Brand.scheme.peachQuartz)
                Divider().frame(height: 42).opacity(0.15)
                SummaryRing(titleKey: "deck.summary.mastered", count: mastered, total: total, color: DS.Brand.scheme.monument)
            }
            .frame(maxWidth: .infinity)
        }
    }
    private struct SummaryRing: View {
        let titleKey: LocalizedStringKey
        let count: Int
        let total: Int
        let color: Color
        var progress: Double { min(1, Double(count) / Double(max(1, total))) }
        var body: some View {
            VStack(spacing: 6) {
                ZStack {
                    Circle().stroke(DS.Palette.border.opacity(0.2), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(color.gradient, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(count)")
                        .font(.headline)
                        .foregroundStyle(color)
                }
                .frame(width: 48, height: 48)
                Text(titleKey)
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct CardPreviewRow: View {
    let card: Flashcard
    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: 6) {
                Text(card.front)
                    .dsType(DS.Font.section)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
                VariantPhraseView(card.back)
                    .dsType(DS.Font.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }
}

private extension DeckDetailView {
    func addNewCardAndEdit() {
        guard let d = deck else { return }
        let insertionIndex = d.cards.count
        let card = Flashcard(front: "", back: "")
        decksStore.addCard(to: d.id, card: card)
        newCardStartIndex = insertionIndex
        // 小延遲以等待列表刷新（避免同幀 push 導致資料未更新）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            navigateToNewEditor = true
        }
    }
}

#Preview {
    let store = FlashcardDecksStore()
    let sampleCards: [Flashcard] = [
        Flashcard(front: "示例正面 A", back: "example back A"),
        Flashcard(front: "示例正面 B", back: "example back B")
    ]
    let deck = store.add(name: "示例卡集", cards: sampleCards)
    return NavigationStack { DeckDetailView(deckID: deck.id) }
        .environmentObject(store)
}
