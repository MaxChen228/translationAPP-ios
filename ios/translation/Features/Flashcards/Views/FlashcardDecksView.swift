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
    @Environment(\.locale) private var locale

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
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                if editController.isEditing {
                                    editController.exitEditMode()
                                }
                            },
                            including: .gesture
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
                        NavigationLink { DeckDetailView(deckID: deck.id) } label: {
                            ShelfTileCard(
                                title: deck.name,
                                subtitle: nil,
                                countText: String(format: String(localized: "deck.cards.count", locale: locale), deck.cards.count),
                                iconSystemName: nil,
                                accentColor: DS.Palette.primary,
                                showChevron: true,
                                progress: deckProgress(deck)
                            )
                        }
                        .buttonStyle(DSCardLinkStyle())
                        .shelfWiggle(isActive: editController.isEditing)
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
                        .onDrag {
                            guard editController.isEditing else { return NSItemProvider() }
                            editController.beginDragging(deck.id)
                            return DeckDragPayload.provider(for: deck.id)
                        }
                        .onDrop(of: [.text], delegate: RootDeckReorderDropDelegate(
                            overDeckID: deck.id,
                            rootIDsProvider: {
                                let r = decksStore.decks.filter { !deckFolders.isInAnyFolder($0.id) }.map { "deck:\($0.id.uuidString)" }
                                return deckOrder.currentOrder(rootIDs: r)
                            },
                            move: { id, to, root in deckOrder.move(id: id, to: to, rootIDs: root) },
                            editController: editController
                        ))
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                if editController.isEditing {
                                    editController.exitEditMode()
                                }
                            },
                            including: .gesture
                        )
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
        .simultaneousGesture(
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
    }
}

// MARK: - Drag/Drop helpers（與題庫本一致的風格）

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
            if let ns = obj as? NSString, let id = DeckDragPayload.decodeDeckID(ns as String) {
                Task { @MainActor in folders.add(deckID: id, to: folderID); Haptics.success() }
                handled = true
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
private struct RootDeckReorderDropDelegate: DropDelegate {
    let overDeckID: UUID
    let rootIDsProvider: () -> [String]
    let move: (String, Int, [String]) -> Void
    let editController: ShelfEditController<UUID>

    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func dropEntered(info: DropInfo) {
        guard let dragging = editController.draggingID else { return }
        let dragKey = "deck:\(dragging.uuidString)"
        let targetKey = "deck:\(overDeckID.uuidString)"
        let root = rootIDsProvider()
        guard let from = root.firstIndex(of: dragKey), let to = root.firstIndex(of: targetKey) else { return }
        if from != to {
            move(dragKey, to, root)
            Haptics.lightTick()
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        editController.endDragging()
        return true
    }
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
