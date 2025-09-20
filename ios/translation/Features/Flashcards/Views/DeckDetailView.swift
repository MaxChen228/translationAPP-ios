import SwiftUI

struct DeckDetailView: View {
    let deckID: UUID
    @EnvironmentObject private var decksStore: FlashcardDecksStore
    @EnvironmentObject private var progressStore: FlashcardProgressStore
    @State private var newEditorRoute: NewEditorRoute?
    @Environment(\.locale) private var locale

    private var deck: PersistedFlashcardDeck? {
        decksStore.decks.first(where: { $0.id == deckID })
    }

    // 二元分類：不熟悉 / 熟悉
    private var counts: (unfamiliar: Int, familiar: Int) {
        guard let d = deck else { return (0,0) }
        var unfamiliar = 0, familiar = 0
        for c in d.cards {
            if progressStore.isFamiliar(deckID: d.id, cardID: c.id) { familiar += 1 } else { unfamiliar += 1 }
        }
        return (unfamiliar, familiar)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if let d = deck {
                    DSSectionHeader(titleText: Text(d.name), subtitleText: Text("deck.detail.subtitle"), accentUnderline: true)

                    // 上：高質感圓環摘要（二環：不熟悉 / 熟悉）
                    DeckSummaryRings(unfamiliar: counts.unfamiliar, familiar: counts.familiar)

                    // 中：行動區（開始複習 → 直接進入整副卡片）
                    NavigationLink {
                        FlashcardsView(title: d.name, cards: d.cards, deckID: d.id)
                    } label: {
                        Text("deck.action.startReview")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DSPrimaryButton())

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
        .navigationDestination(item: $newEditorRoute) { route in
            if let targetDeck = deck(for: route.deckID) {
                FlashcardsView(
                    title: targetDeck.name,
                    cards: targetDeck.cards,
                    deckID: targetDeck.id,
                    startIndex: route.startIndex,
                    startEditing: true
                )
            } else {
                Text(String(localized: "deck.notFound", locale: locale))
                    .foregroundStyle(.secondary)
            }
        }
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
                        .shadow(color: DS.Shadow.overlay.color, radius: DS.Shadow.overlay.radius, x: DS.Shadow.overlay.x, y: DS.Shadow.overlay.y)
                        .accessibilityLabel(Text("deck.action.addCard"))
                    }
            }
        }
        .navigationTitle(Text("nav.deck"))
    }
}

// 高質感圓環摘要：以 3 欄圓環 + 標題呈現，節省高度且資訊清晰
private struct DeckSummaryRings: View {
    let unfamiliar: Int
    let familiar: Int
    var total: Int { max(1, unfamiliar + familiar) }
    @Environment(\.locale) private var locale
    var body: some View {
        DSCard {
            HStack(spacing: 0) {
                SummaryRing(titleKey: "deck.summary.unfamiliar", count: unfamiliar, total: total, color: DS.Brand.scheme.peachQuartz)
                Divider().frame(height: 42).opacity(0.15)
                SummaryRing(titleKey: "deck.summary.familiar", count: familiar, total: total, color: DS.Palette.success)
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
    struct NewEditorRoute: Identifiable, Hashable {
        let id = UUID()
        let deckID: UUID
        let startIndex: Int
    }

    func deck(for id: UUID) -> PersistedFlashcardDeck? {
        decksStore.decks.first(where: { $0.id == id })
    }

    func addNewCardAndEdit() {
        guard let d = deck else { return }
        let insertionIndex = d.cards.count
        let card = Flashcard(front: "", back: "")
        decksStore.addCard(to: d.id, card: card)
        // 小延遲以等待列表刷新（避免同幀 push 導致資料未更新）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            newEditorRoute = NewEditorRoute(deckID: d.id, startIndex: insertionIndex)
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
