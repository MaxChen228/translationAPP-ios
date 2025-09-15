import SwiftUI

struct DeckDetailView: View {
    let deckID: UUID
    @EnvironmentObject private var decksStore: FlashcardDecksStore

    private var deck: PersistedFlashcardDeck? {
        decksStore.decks.first(where: { $0.id == deckID })
    }

    // Simple counters (v1): treat all as 未學習；後續接入進度資料再更新
    private var counts: (new: Int, learning: Int, mastered: Int) {
        let total = deck?.cards.count ?? 0
        return (new: total, learning: 0, mastered: 0)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if let d = deck {
                    DSSectionHeader(title: d.name, subtitle: "單字卡集詳情", accentUnderline: true)

                    // 上：三個狀態卡（先展示統計）
                    VStack(spacing: 10) {
                        StatusCard(title: "未學習", count: counts.new, color: DS.Brand.scheme.provence)
                        StatusCard(title: "仍在學習", count: counts.learning, color: DS.Brand.scheme.peachQuartz)
                        StatusCard(title: "已精通", count: counts.mastered, color: DS.Brand.scheme.monument)
                    }

                    // 中：行動區（開始複習 → 直接進入整副卡片）
                    NavigationLink {
                        FlashcardsView(title: d.name, cards: d.cards, deckID: d.id)
                    } label: {
                        Text("開始複習")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DSPrimaryButton())

                    // 下：卡片簡略列表
                    Text("詞語").dsType(DS.Font.section)
                    VStack(spacing: 10) {
                        ForEach(d.cards) { card in
                            NavigationLink {
                                // 進入學習頁，從該卡開始（簡化：目前直接進入整副，未定位 index）
                                FlashcardsView(title: d.name, cards: d.cards, deckID: d.id)
                            } label: {
                                CardPreviewRow(card: card)
                            }
                            .buttonStyle(DSCardLinkStyle())
                        }
                    }
                } else {
                    Text("找不到卡片集").foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        .navigationTitle("單字卡")
    }
}

private struct StatusCard: View {
    let title: String
    let count: Int
    let color: Color
    var body: some View {
        DSOutlineCard {
            HStack(spacing: 12) {
                ZStack {
                    Circle().stroke(DS.Palette.border.opacity(0.25), lineWidth: 10)
                    Text("\(count)")
                        .font(.headline)
                        .foregroundStyle(color)
                }
                .frame(width: 52, height: 52)

                Text(title)
                    .dsType(DS.Font.section)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
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
                VariantPhraseView(card.back)
                    .dsType(DS.Font.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

#Preview {
    let store = FlashcardDecksStore()
    let deck = store.add(name: "示例卡集", cards: SampleDecks.gratitudeAndChoices.cards)
    return NavigationStack { DeckDetailView(deckID: deck.id) }
        .environmentObject(store)
}

