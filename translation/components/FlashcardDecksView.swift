import SwiftUI

struct FlashcardDeck: Identifiable, Equatable {
    let id: UUID
    var name: String
    var cards: [Flashcard]
    init(id: UUID = UUID(), name: String, cards: [Flashcard]) {
        self.id = id; self.name = name; self.cards = cards
    }
}

struct FlashcardDecksView: View {
    @EnvironmentObject private var decksStore: FlashcardDecksStore
    @EnvironmentObject private var deckFolders: DeckFoldersStore
    @EnvironmentObject private var deckOrder: DeckRootOrderStore
    private var cols: [GridItem] { [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.sm2)] }
    @State private var renaming: PersistedFlashcardDeck? = nil
    @State private var renamingFolder: DeckFolder? = nil
    @State private var draggingDeckID: UUID? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                Text("單字卡集")
                    .dsType(DS.Font.section)
                    .fontWeight(.semibold)
                Text("選擇一個卡片集開始練習")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)

                // 資料夾區（外觀與題庫本一致）
                if !deckFolders.folders.isEmpty {
                    ShelfGrid(title: "資料夾", columns: cols) {
                        ForEach(deckFolders.folders) { folder in
                            NavigationLink { DeckFolderDetailView(folderID: folder.id) } label: {
                                ShelfTileCard(title: folder.name, subtitle: nil, countText: "共 \(folder.deckIDs.count) 個", iconSystemName: "folder", accentColor: DS.Brand.scheme.monument, showChevron: true)
                            }
                            .buttonStyle(DSCardLinkStyle())
                            .contextMenu {
                                Button("重新命名") { renamingFolder = folder }
                                Button("刪除", role: .destructive) { _ = deckFolders.removeFolder(folder.id) }
                            }
                            .onDrop(of: [.text], delegate: DeckIntoFolderDropDelegate(folderID: folder.id, folders: deckFolders, draggingDeckID: $draggingDeckID))
                        }
                        Button { _ = deckFolders.addFolder() } label: { NewDeckFolderCard() }
                            .buttonStyle(.plain)
                    }
                    DSSeparator(color: DS.Palette.border.opacity(0.2))
                }

                // 根層單字卡集（未分到資料夾）＋ 依自訂順序排序（與題庫本相同模式）
                let rootDecks: [PersistedFlashcardDeck] = decksStore.decks.filter { !deckFolders.isInAnyFolder($0.id) }
                let rootIDs = rootDecks.map { "deck:\($0.id.uuidString)" }
                let orderedIDs = deckOrder.currentOrder(rootIDs: rootIDs)
                let orderedRootDecks: [PersistedFlashcardDeck] = orderedIDs.compactMap { tid in
                    guard tid.hasPrefix("deck:"), let did = UUID(uuidString: String(tid.dropFirst(5))) else { return nil }
                    return rootDecks.first(where: { $0.id == did })
                }

                ShelfGrid(title: "單字卡集", columns: cols) {
                    ForEach(orderedRootDecks) { deck in
                        NavigationLink { DeckDetailView(deckID: deck.id) } label: {
                            ShelfTileCard(
                                title: deck.name,
                                subtitle: nil,
                                countText: "共 \(deck.cards.count) 張",
                                iconSystemName: nil,
                                accentColor: DS.Palette.primary,
                                showChevron: true
                            )
                        }
                        .buttonStyle(DSCardLinkStyle())
                        .contextMenu {
                            Button("重新命名") { renaming = deck }
                            Button("刪除", role: .destructive) {
                                decksStore.remove(deck.id)
                                deckOrder.removeFromOrder("deck:\(deck.id.uuidString)")
                            }
                        }
                        .onDrag { draggingDeckID = deck.id; return DeckDragPayload.provider(for: deck.id) }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        .navigationTitle("單字卡")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { _ = deckFolders.addFolder() } label: { Label("新資料夾", systemImage: "folder.badge.plus") }
            }
        }
        .onDrop(of: [.text], delegate: ClearDeckDragStateDropDelegate(draggingDeckID: $draggingDeckID))
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
    @Binding var draggingDeckID: UUID?

    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.text])
        guard let p = providers.first else { draggingDeckID = nil; return false }
        var handled = false
        _ = p.loadObject(ofClass: NSString.self) { obj, _ in
            if let ns = obj as? NSString, let id = DeckDragPayload.decodeDeckID(ns as String) {
                Task { @MainActor in folders.add(deckID: id, to: folderID); Haptics.success() }
                handled = true
            }
        }
        draggingDeckID = nil
        return handled
    }
}

private struct ClearDeckDragStateDropDelegate: DropDelegate {
    @Binding var draggingDeckID: UUID?
    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { draggingDeckID = nil; return true }
}

// DeckDragPayload is defined in DeckFolderViews.swift and reused here.

private struct DeckCard: View {
    let name: String
    let count: Int
    var body: some View {
        ShelfTileCard(title: name, subtitle: nil, countText: "共 \(count) 張", iconSystemName: nil, accentColor: DS.Palette.primary, showChevron: true)
    }
}

