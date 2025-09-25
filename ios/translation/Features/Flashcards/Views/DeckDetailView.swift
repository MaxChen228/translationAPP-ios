import SwiftUI

struct DeckDetailView: View {
    let deckID: UUID
    @EnvironmentObject private var decksStore: FlashcardDecksStore
    @EnvironmentObject private var progressStore: FlashcardProgressStore
    @State private var newEditorRoute: NewEditorRoute?
    @StateObject private var editController = ShelfEditController<UUID>()
    @State private var showBulkDeleteConfirm = false
    @State private var showMoveSheet = false
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
                    let selectedCount = editController.selectedIDs.count

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
                    .buttonStyle(DSButton(style: .secondary, size: .full))

                    // 下：卡片簡略列表（新增改為懸浮按鈕，避免擁擠）
                    Text("deck.words.title").dsType(DS.Font.section)
                    VStack(spacing: 10) {
                        ForEach(d.cards) { card in
                            if let idx = d.cards.firstIndex(where: { $0.id == card.id }) {
                                cardTile(for: d, card: card, index: idx)
                            }
                        }
                    }
                    .padding(.top, editController.isEditing && selectedCount > 0 ? DS.Spacing.xl : 0)
                    .overlay(alignment: .topTrailing) {
                        if editController.isEditing, selectedCount > 0 {
                            DeckDetailBulkToolbar(
                                count: selectedCount,
                                canMove: decksStore.decks.contains(where: { $0.id != d.id }),
                                onDelete: { showBulkDeleteConfirm = true },
                                onMove: { showMoveSheet = true }
                            )
                            .padding(.top, DS.Spacing.xs)
                            .padding(.trailing, DS.Spacing.xs)
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
        .contentShape(Rectangle())
        .gesture(
            TapGesture().onEnded {
                if editController.isEditing {
                    editController.exitEditMode()
                }
            },
            including: .gesture
        )
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
        .onAppear { editController.exitEditMode() }
        .confirmationDialog(
            String(localized: "deck.bulkDelete.confirm", defaultValue: "Delete selected cards?"),
            isPresented: $showBulkDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "action.deleteAll", defaultValue: "Delete All"), role: .destructive) {
                deleteSelectedCards()
                showBulkDeleteConfirm = false
            }
            Button(String(localized: "action.cancel", locale: locale), role: .cancel) {
                showBulkDeleteConfirm = false
            }
        }
        .sheet(isPresented: $showMoveSheet) {
            if let currentDeck = deck {
                DeckPickerSheet(
                    decks: decksStore.decks.filter { $0.id != currentDeck.id },
                    onSelect: { target in
                        moveSelectedCards(to: target.id)
                        showMoveSheet = false
                    },
                    onCancel: { showMoveSheet = false }
                )
            } else {
                EmptyView()
            }
        }
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

private struct DeckDetailBulkToolbar: View {
    var count: Int
    var canMove: Bool
    var onDelete: () -> Void
    var onMove: () -> Void

    @Environment(\.locale) private var locale

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button(action: onDelete) {
                Label {
                    Text(String(localized: "action.delete", locale: locale))
                } icon: {
                    Image(systemName: "trash")
                }
            }
            .buttonStyle(DSButton(style: .secondary, size: .compact))

            Button(action: onMove) {
                Label {
                    Text(String(localized: "deck.move.action", defaultValue: "Move"))
                } icon: {
                    Image(systemName: "folder")
                }
            }
            .buttonStyle(DSButton(style: .secondary, size: .compact))
            .disabled(!canMove)

            Text(String(format: String(localized: "bulk.selectionCount", defaultValue: "已選 %d 項"), count))
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DS.Spacing.xs)
        .padding(.horizontal, DS.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
                .shadow(color: DS.Shadow.card.color.opacity(0.4), radius: DS.Shadow.card.radius, x: DS.Shadow.card.x, y: DS.Shadow.card.y)
        )
    }
}

private struct DeckPickerSheet: View {
    var decks: [PersistedFlashcardDeck]
    var onSelect: (PersistedFlashcardDeck) -> Void
    var onCancel: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            List {
                if decks.isEmpty {
                    Text(String(localized: "deck.move.empty", defaultValue: "目前沒有其他單字卡集可供移動"))
                        .foregroundStyle(.secondary)
                } else {
                    Section {
                        ForEach(decks) { deck in
                            Button {
                                onSelect(deck)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(deck.name)
                                    Spacer()
                                    Text(String(format: String(localized: "deck.cards.count", locale: locale), deck.cards.count))
                                        .dsType(DS.Font.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(Text(String(localized: "deck.move.title", defaultValue: "選擇目標單字卡集")))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel", locale: locale)) {
                        onCancel()
                        dismiss()
                    }
                }
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
                    .font(.custom("Songti SC", size: 18, relativeTo: .body))
                    .fontWeight(.medium)
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

    @ViewBuilder
    func cardTile(for deck: PersistedFlashcardDeck, card: Flashcard, index: Int) -> some View {
        let isEditing = editController.isEditing
        let isSelected = editController.isSelected(card.id)

        if isEditing {
            CardPreviewRow(card: card)
                .shelfSelectable(isEditing: true, isSelected: isSelected)
                .shelfWiggle(isActive: true)
                .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                .highPriorityGesture(
                    TapGesture().onEnded {
                        editController.toggleSelection(card.id)
                    }
                )
        } else {
            ZStack(alignment: .topTrailing) {
                NavigationLink {
                    FlashcardsView(title: deck.name, cards: deck.cards, deckID: deck.id, startIndex: index)
                } label: {
                    CardPreviewRow(card: card)
                        .shelfSelectable(isEditing: false, isSelected: false)
                }
                .buttonStyle(DSCardLinkStyle())

                DSQuickActionIconButton(
                    systemName: "square.and.pencil",
                    labelKey: "action.edit",
                    action: {
                        newEditorRoute = NewEditorRoute(deckID: deck.id, startIndex: index)
                    },
                    shape: .circle,
                    style: .outline,
                    size: 28
                )
                .padding(.trailing, DS.Spacing.sm)
                .padding(.top, DS.Spacing.sm)
            }
            .shelfWiggle(isActive: false)
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                    editController.enterEditMode()
                    editController.setSelection([card.id])
                    Haptics.medium()
                }
            )
        }
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

    func deleteSelectedCards() {
        guard let currentDeck = deck else { return }
        let orderedIDs = orderedSelection(in: currentDeck)
        guard !orderedIDs.isEmpty else { return }

        let removed = decksStore.removeCards(Set(orderedIDs), from: currentDeck.id)
        for card in removed {
            progressStore.markUnfamiliar(deckID: currentDeck.id, cardID: card.id)
        }
        editController.clearSelection()
        Haptics.success()
    }

    func moveSelectedCards(to targetDeckID: UUID) {
        guard let currentDeck = deck, currentDeck.id != targetDeckID else { return }
        let orderedIDs = orderedSelection(in: currentDeck)
        guard !orderedIDs.isEmpty else { return }

        let familiarIDs = orderedIDs.filter { progressStore.isFamiliar(deckID: currentDeck.id, cardID: $0) }
        let moved = decksStore.moveCards(orderedIDs, from: currentDeck.id, to: targetDeckID)
        guard !moved.isEmpty else { return }

        for id in orderedIDs {
            progressStore.markUnfamiliar(deckID: currentDeck.id, cardID: id)
        }
        for id in familiarIDs {
            progressStore.markFamiliar(deckID: targetDeckID, cardID: id)
        }
        editController.clearSelection()
        editController.exitEditMode()
        Haptics.success()
    }

    func orderedSelection(in deck: PersistedFlashcardDeck) -> [UUID] {
        let selected = editController.selectedIDs
        guard !selected.isEmpty else { return [] }
        return deck.cards.compactMap { selected.contains($0.id) ? $0.id : nil }
    }
}

#Preview {
    let store = FlashcardDecksStore()
    let sampleCards = FlashcardSessionStore.defaultCards
    let deck = store.add(name: String(localized: "flashcards.sampleDeck.name"), cards: sampleCards)
    return NavigationStack { DeckDetailView(deckID: deck.id) }
        .environmentObject(store)
}
