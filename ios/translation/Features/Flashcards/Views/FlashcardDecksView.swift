import SwiftUI

struct FlashcardDecksView: View {
    @EnvironmentObject private var decksStore: FlashcardDecksStore
    @EnvironmentObject private var deckFolders: DeckFoldersStore
    @EnvironmentObject private var deckOrder: DeckRootOrderStore
    @EnvironmentObject private var progressStore: FlashcardProgressStore
    private var cols: [GridItem] { [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.sm2)] }
    @State private var renaming: PersistedFlashcardDeck? = nil
    @State private var renamingFolder: DeckFolder? = nil
    @StateObject private var editController = ShelfEditController<UUID>()
    @State private var showBulkDeleteConfirm = false
    @Environment(\.locale) private var locale

    private var selectedCount: Int { editController.selectedIDs.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // 頂部大標移除，避免與下方區塊標題重複

                // 資料夾區（外觀與題庫本一致）—即使為 0 也顯示新增卡
                ShelfGrid(titleKey: "deck.folders.title", columns: cols) {
                    ForEach(deckFolders.folders) { folder in
                        NavigationLink { DeckFolderDetailView(folderID: folder.id) } label: {
                            ShelfTileCard(title: folder.name, subtitle: nil, countText: String(format: String(localized: "folder.decks.count", locale: locale), folder.deckIDs.count), iconSystemName: "folder", accentColor: DS.Brand.scheme.monument, showChevron: true)
                        }
                        .buttonStyle(DSCardLinkStyle())
                        .contextMenu {
                            Button(String(localized: "action.edit", locale: locale)) {
                                editController.enterEditMode()
                                Haptics.medium()
                            }
                            Button(String(localized: "action.rename", locale: locale)) { renamingFolder = folder }
                            Button(String(localized: "action.delete", locale: locale), role: .destructive) { _ = deckFolders.removeFolder(folder.id) }
                        }
                        .onDrop(of: [.text], delegate: DeckIntoFolderDropDelegate(folderID: folder.id, folders: deckFolders, editController: editController))
                        .simultaneousGesture(
                            editController.isEditing ?
                            TapGesture().onEnded {
                                editController.exitEditMode()
                            } : nil
                        )
                    }
                    Button { _ = deckFolders.addFolder(name: String(localized: "folder.new", locale: locale)) } label: { NewDeckFolderCard() }
                        .buttonStyle(.plain)
                }
                DSSeparator(color: DS.Palette.border.opacity(0.2))

                // 根層單字卡集（未分到資料夾）＋ 依自訂順序排序（與題庫本相同模式）
                let rootDecks: [PersistedFlashcardDeck] = decksStore.decks.filter { !deckFolders.isInAnyFolder($0.id) }
                let rootIDs = rootDecks.map { "deck:\($0.id.uuidString)" }
                let orderedIDs = deckOrder.currentOrder(rootIDs: rootIDs)
                let orderedRootDecks: [PersistedFlashcardDeck] = orderedIDs.compactMap { tid in
                    guard tid.hasPrefix("deck:"), let did = UUID(uuidString: String(tid.dropFirst(5))) else { return nil }
                    return rootDecks.first(where: { $0.id == did })
                }

                ShelfGrid(titleKey: "deck.root.title", columns: cols) {
                    // Browse cloud curated decks → copy to local
                    NavigationLink { CloudDeckLibraryView() } label: {
                        BrowseCloudCard(titleKey: "deck.browseCloud")
                    }
                    .buttonStyle(.plain)
                    .disabled(editController.isEditing)

                    // New deck tile (similar look to NewDeckFolderCard)
                    Button {
                        editController.exitEditMode()
                        let deck = decksStore.add(name: String(localized: "deck.untitled", locale: locale), cards: [])
                        renaming = deck
                    } label: { NewDeckCard() }
                    .buttonStyle(.plain)

                    ForEach(orderedRootDecks) { deck in
                        let isEditing = editController.isEditing
                        let isSelected = editController.isSelected(deck.id)
                        let card = ShelfTileCard(
                            title: deck.name,
                            subtitle: nil,
                            countText: String(format: String(localized: "deck.cards.count", locale: locale), deck.cards.count),
                            iconSystemName: nil,
                            accentColor: DS.Palette.primary,
                            showChevron: true,
                            progress: deckProgress(deck)
                        )
                        .shelfSelectable(isEditing: isEditing, isSelected: isSelected)

                        Group {
                            if isEditing {
                                card
                                    .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                                    .highPriorityGesture(
                                        TapGesture().onEnded {
                                            editController.toggleSelection(deck.id)
                                        }
                                    )
                                    .contextMenu {
                                        Button(String(localized: "action.rename", locale: locale)) {
                                            renaming = deck
                                        }
                                        Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                                            decksStore.remove(deck.id)
                                            deckOrder.removeFromOrder("deck:\(deck.id.uuidString)")
                                        }
                                    }
                            } else {
                                NavigationLink { DeckDetailView(deckID: deck.id) } label: {
                                    card
                                }
                                .buttonStyle(DSCardLinkStyle())
                                .contextMenu {
                                    Button(String(localized: "action.edit", locale: locale)) {
                                        editController.enterEditMode()
                                        Haptics.medium()
                                    }
                                    Button(String(localized: "action.rename", locale: locale)) {
                                        editController.exitEditMode()
                                        renaming = deck
                                    }
                                    Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                                        editController.exitEditMode()
                                        decksStore.remove(deck.id)
                                        deckOrder.removeFromOrder("deck:\(deck.id.uuidString)")
                                    }
                                }
                            }
                        }
                        .shelfWiggle(isActive: isEditing)
                        .shelfConditionalDrag(isEditing) {
                            editController.beginDragging(deck.id)
                            let payload = ShelfDragPayload(
                                primaryID: deck.id.uuidString,
                                selectedIDs: orderedSelection(anchor: deck.id, ordered: orderedRootDecks.map { $0.id })
                                    .map { $0.uuidString }
                            )
                            return NSItemProvider(object: payload.encodedString() as NSString)
                        }
                        .onDrop(of: [.text], delegate: DeckRootReorderDropDelegate(
                            overDeckID: deck.id,
                            editController: editController,
                            decksStore: decksStore,
                            deckFolders: deckFolders,
                            deckOrder: deckOrder
                        ))
                }
            }
            .overlay(alignment: .topTrailing) {
                if editController.isEditing, selectedCount > 0 {
                    DeckBulkToolbar(count: selectedCount) {
                            showBulkDeleteConfirm = true
                        }
                        .padding(.top, DS.Spacing.sm)
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        .navigationTitle(Text("nav.deck"))
        .id(locale.identifier)
        .toolbar { }
        .onDrop(of: [.text], delegate: ClearDeckDragStateDropDelegate(editController: editController))
        .contentShape(Rectangle())
        .gesture(
            TapGesture().onEnded {
                if editController.isEditing {
                    editController.exitEditMode()
                }
            },
            including: .gesture
        )
        .onAppear { editController.exitEditMode() }
        .sheet(item: $renaming) { dk in
            RenameSheet(name: dk.name) { new in decksStore.rename(dk.id, to: new) }
                .presentationDetents([.height(180)])
        }
        .sheet(item: $renamingFolder) { f in
            RenameSheet(name: f.name) { new in deckFolders.rename(f.id, to: new) }
                .presentationDetents([.height(180)])
        }
        .confirmationDialog(String(localized: "deck.bulkDelete.confirm", defaultValue: "Delete selected decks?"), isPresented: $showBulkDeleteConfirm, titleVisibility: .visible) {
            Button(String(localized: "action.deleteAll", defaultValue: "Delete All"), role: .destructive) {
                deleteSelectedDecks()
                showBulkDeleteConfirm = false
            }
            Button(String(localized: "action.cancel", locale: locale), role: .cancel) {
                showBulkDeleteConfirm = false
            }
        }
    }
}

private extension FlashcardDecksView {
    func orderedSelection(anchor: UUID, ordered: [UUID]) -> [UUID] {
        let selected = editController.selectedIDs
        guard selected.contains(anchor), !selected.isEmpty else { return [anchor] }
        let orderedMatch = ordered.filter { selected.contains($0) }
        return orderedMatch.isEmpty ? [anchor] : orderedMatch
    }

    func deleteSelectedDecks() {
        let ids = editController.selectedIDs
        guard !ids.isEmpty else { return }
        for id in ids {
            decksStore.remove(id)
            deckOrder.removeFromOrder("deck:\(id.uuidString)")
        }
        editController.clearSelection()
    }
}

// MARK: - Drag/Drop helpers（與題庫本一致的風格）

private struct DeckBulkToolbar: View {
    var count: Int
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button(action: onDelete) {
                Label(String(localized: "action.deleteAll", defaultValue: "Delete All"), systemImage: "trash")
            }
            .buttonStyle(DSButton(style: .secondary, size: .compact))

            Text(String(format: String(localized: "bulk.selectionCount", defaultValue: "已選 %d 項"), count))
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct DeckIntoFolderDropDelegate: DropDelegate {
    let folderID: UUID
    let folders: DeckFoldersStore
    let editController: ShelfEditController<UUID>

    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.text])
        guard let p = providers.first else { editController.endDragging(); return false }
        var handled = false
        _ = p.loadObject(ofClass: NSString.self) { obj, _ in
            if let ns = obj as? NSString {
                let payload = ShelfDragPayload.decode(from: ns as String)
                let ids = payload.selectedIDs.isEmpty ? [payload.primaryID] : payload.selectedIDs
                let deckIDs = ids.compactMap(UUID.init(uuidString:))
                if !deckIDs.isEmpty {
                    Task { @MainActor in
                        for id in deckIDs {
                            folders.add(deckID: id, to: folderID)
                        }
                        editController.clearSelection()
                        Haptics.success()
                    }
                    handled = true
                }
            }
        }
        editController.endDragging()
        return handled
    }
}

private struct ClearDeckDragStateDropDelegate: DropDelegate {
    let editController: ShelfEditController<UUID>
    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        editController.endDragging()
        return true
    }
}

// DeckDragPayload is defined in DeckFolderViews.swift and reused here.

// Root 層簡易換位：拖曳 deck 到另一個 deck 上方即移動到該索引。
private struct DeckRootReorderDropDelegate: DropDelegate {
    let overDeckID: UUID
    let editController: ShelfEditController<UUID>
    let decksStore: FlashcardDecksStore
    let deckFolders: DeckFoldersStore
    let deckOrder: DeckRootOrderStore

    func validateDrop(info: DropInfo) -> Bool { editController.isEditing }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func dropEntered(info: DropInfo) {
        guard editController.isEditing, let dragging = editController.draggingID else { return }
        let selection = orderedSelection(anchor: dragging)
        guard !selection.contains(overDeckID) else { return }

        let rootIDs = currentRootIDsOrdered()
        let targetKey = key(for: overDeckID)
        let moving = selection.map { key(for: $0) }
        deckOrder.move(ids: moving, before: targetKey, rootIDs: rootIDs)
        Haptics.lightTick()
    }

    func performDrop(info: DropInfo) -> Bool {
        guard editController.isEditing else { return false }
        editController.endDragging()
        Haptics.success()
        return true
    }

    private func orderedSelection(anchor: UUID) -> [UUID] {
        let selected = editController.selectedIDs
        guard selected.contains(anchor), !selected.isEmpty else { return [anchor] }
        let ordered = currentRootIDsOrdered().compactMap { key -> UUID? in
            guard key.hasPrefix("deck:"), let id = UUID(uuidString: String(key.dropFirst(5))) else { return nil }
            return selected.contains(id) ? id : nil
        }
        return ordered.isEmpty ? [anchor] : ordered
    }

    private func currentRootIDsOrdered() -> [String] {
        let root = decksStore.decks.filter { !deckFolders.isInAnyFolder($0.id) }.map { key(for: $0.id) }
        return deckOrder.currentOrder(rootIDs: root)
    }

    private func key(for id: UUID) -> String { "deck:\(id.uuidString)" }

}

private struct DeckCard: View {
    let name: String
    let count: Int
    @Environment(\.locale) private var locale
    var body: some View {
        ShelfTileCard(title: name, subtitle: nil, countText: String(format: String(localized: "deck.cards.count", locale: locale), count), iconSystemName: nil, accentColor: DS.Palette.primary, showChevron: true)
    }
}

// A dashed-outline card to create a new deck, visually consistent with NewDeckFolderCard.
private struct NewDeckCard: View {
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.badge.plus").font(.title3)
            Text(String(localized: "deck.new", locale: locale)).dsType(DS.Font.caption).foregroundStyle(.secondary)
        }
        .frame(minHeight: DS.CardSize.minHeightCompact)
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.md)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: DS.BorderWidth.regular, dash: [5, 4]))
                .foregroundStyle(DS.Palette.border.opacity(0.45))
        )
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }
}

// MARK: - Progress helpers

private struct BrowseCloudCard: View {
    var titleKey: LocalizedStringKey
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "icloud.and.arrow.down").font(.title3)
            Text(titleKey).dsType(DS.Font.caption).foregroundStyle(.secondary)
        }
        .frame(minHeight: DS.CardSize.minHeightCompact)
        .frame(maxWidth: .infinity)
        .padding(DS.Spacing.md)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: DS.BorderWidth.regular, dash: [5, 4]))
                .foregroundStyle(DS.Palette.border.opacity(0.45))
        )
        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
    }
}

extension FlashcardDecksView {
    // 進度以「熟悉比例」計算：familiar / total
    private func deckProgress(_ deck: PersistedFlashcardDeck) -> Double {
        guard !deck.cards.isEmpty else { return 0 }
        var familiar = 0
        for c in deck.cards { if progressStore.isFamiliar(deckID: deck.id, cardID: c.id) { familiar += 1 } }
        return max(0, min(1, Double(familiar) / Double(deck.cards.count)))
    }
}
