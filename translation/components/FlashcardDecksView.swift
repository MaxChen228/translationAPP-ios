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
    @State private var draggingTileID: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                DSSectionHeader(title: "單字卡集", subtitle: "選擇一個卡片集開始練習", accentUnderline: true)

                // 合併：資料夾 + 未分組單字卡（像手機桌面）
                let rootDecks: [PersistedFlashcardDeck] = decksStore.decks.filter { !deckFolders.isInAnyFolder($0.id) }
                let folderIDs = deckFolders.folders.map { "folder:\($0.id.uuidString)" }
                let deckIDs = rootDecks.map { "deck:\($0.id.uuidString)" }
                let rootIDs = folderIDs + deckIDs
                let orderedIDs = deckOrder.currentOrder(rootIDs: rootIDs)

                ShelfGrid {
                    ForEach(orderedIDs, id: \.self) { tid in
                        if tid.hasPrefix("folder:"), let fid = UUID(uuidString: String(tid.dropFirst(7))), let folder = deckFolders.folders.first(where: { $0.id == fid }) {
                            NavigationLink { DeckFolderDetailView(folderID: folder.id) } label: {
                                ShelfTileCard(title: folder.name, subtitle: nil, countText: "共 \(folder.deckIDs.count) 個", iconSystemName: "folder", accentColor: DS.Brand.scheme.monument, showChevron: true)
                            }
                            .buttonStyle(DSCardLinkStyle())
                            .contextMenu {
                                Button("重新命名") { renamingFolder = folder }
                                Button("刪除", role: .destructive) { _ = deckFolders.removeFolder(folder.id); deckOrder.removeFromOrder("folder:\(folder.id.uuidString)") }
                            }
                            .onDrag { draggingTileID = tid; return NSItemProvider(object: tid as NSString) }
                            .onDrop(of: [.text], delegate: DeckRootTileDropDelegate(
                                overID: tid,
                                overKind: .folder(folder.id),
                                draggingID: $draggingTileID,
                                rootIDsProvider: { deckFolders.folders.map { "folder:\($0.id.uuidString)" } + decksStore.decks.filter { !deckFolders.isInAnyFolder($0.id) }.map { "deck:\($0.id.uuidString)" } },
                                move: { id, to, root in deckOrder.move(id: id, to: to, rootIDs: root) },
                                addDeckToFolder: { deckID, folderID in deckFolders.add(deckID: deckID, to: folderID); deckOrder.removeFromOrder("deck:\(deckID.uuidString)") },
                                createFolderFromDecks: { _, _, _ in }
                            ))
                        } else if tid.hasPrefix("deck:"), let did = UUID(uuidString: String(tid.dropFirst(5))), let deck = rootDecks.first(where: { $0.id == did }) {
                            NavigationLink { DeckDetailView(deckID: deck.id) } label: {
                                DeckCard(name: deck.name, count: deck.cards.count)
                            }
                            .buttonStyle(DSCardLinkStyle())
                            .contextMenu {
                                Button("重新命名") { renaming = deck }
                                Button("刪除", role: .destructive) { deckFolders.remove(deckID: deck.id); decksStore.remove(deck.id); deckOrder.removeFromOrder("deck:\(deck.id.uuidString)") }
                            }
                            .onDrag { draggingTileID = tid; return NSItemProvider(object: tid as NSString) }
                            .onDrop(of: [.text], delegate: DeckRootTileDropDelegate(
                                overID: tid,
                                overKind: .deck(deck.id),
                                draggingID: $draggingTileID,
                                rootIDsProvider: { deckFolders.folders.map { "folder:\($0.id.uuidString)" } + decksStore.decks.filter { !deckFolders.isInAnyFolder($0.id) }.map { "deck:\($0.id.uuidString)" } },
                                move: { id, to, root in deckOrder.move(id: id, to: to, rootIDs: root) },
                                addDeckToFolder: { deckID, folderID in deckFolders.add(deckID: deckID, to: folderID); deckOrder.removeFromOrder("deck:\(deckID.uuidString)") },
                                createFolderFromDecks: { a, b, insertAt in
                                    let folder = deckFolders.addFolder()
                                    deckFolders.add(deckID: a, to: folder.id)
                                    deckFolders.add(deckID: b, to: folder.id)
                                    deckOrder.removeFromOrder("deck:\(a.uuidString)")
                                    deckOrder.removeFromOrder("deck:\(b.uuidString)")
                                    let current = deckFolders.folders.map { "folder:\($0.id.uuidString)" } + decksStore.decks.filter { !deckFolders.isInAnyFolder($0.id) }.map { "deck:\($0.id.uuidString)" }
                                    deckOrder.insertIntoOrder("folder:\(folder.id.uuidString)", at: insertAt, rootIDs: current)
                                    renamingFolder = folder
                                }
                            ))
                        }
                    }
                    .dsAnimation(DS.AnimationToken.reorder, value: deckOrder.order)
                }

                // 新資料夾 tile 放在末端
                ShelfGrid { Button { _ = deckFolders.addFolder() } label: { NewDeckFolderCard() }.buttonStyle(.plain) }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        // 後備 drop：把項目拖到空白處或邊緣放下時清除 dragging 狀態
        .onDrop(of: [.text], delegate: ShelfClearDragStateDrop(draggingID: $draggingTileID))
        .navigationTitle("單字卡")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { _ = deckFolders.addFolder() } label: { Label("新資料夾", systemImage: "folder.badge.plus") }
            }
        }
        .sheet(item: $renaming) { dk in
            RenameSheet(name: dk.name) { new in
                decksStore.rename(dk.id, to: new)
            }
            .presentationDetents([.height(180)])
        }
        .sheet(item: $renamingFolder) { f in
            RenameSheet(name: f.name) { new in
                deckFolders.rename(f.id, to: new)
            }
            .presentationDetents([.height(180)])
        }
    }
}

private struct DeckCard: View {
    let name: String
    let count: Int
    var body: some View {
        ShelfTileCard(title: name, subtitle: nil, countText: "共 \(count) 張", iconSystemName: nil, accentColor: DS.Palette.primary, showChevron: true)
    }
}

private struct DeckItemLink: View {
    let deck: PersistedFlashcardDeck
    var onRename: () -> Void
    var onDelete: () -> Void
    var body: some View {
        NavigationLink {
            DeckDetailView(deckID: deck.id)
        } label: {
            DeckCard(name: deck.name, count: deck.cards.count)
                .contextMenu {
                    Button("重新命名") { onRename() }
                    Button("刪除", role: .destructive) { onDelete() }
                }
        }
        .buttonStyle(DSCardLinkStyle())
    }
}

// MARK: - Drag/Drop Helpers (root reordering, folder drop)

private enum RootTileKind { case folder(UUID), deck(UUID) }

private struct DeckRootTileDropDelegate: DropDelegate {
    let overID: String
    let overKind: RootTileKind
    @Binding var draggingID: String?
    let rootIDsProvider: () -> [String]
    let move: (String, Int, [String]) -> Void
    let addDeckToFolder: (UUID, UUID) -> Void
    let createFolderFromDecks: (UUID, UUID, Int) -> Void

    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != overID else { return }
        let root = rootIDsProvider()
        guard let from = root.firstIndex(of: draggingID), let to = root.firstIndex(of: overID) else { return }
        move(draggingID, to > from ? to + 1 : to, root)
        Haptics.lightTick()
    }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.text])
        guard let p = providers.first else { draggingID = nil; return false }
        var handled = false
        _ = p.loadObject(ofClass: NSString.self) { obj, _ in
            guard let s = obj as? NSString else { return }
            let str = s as String
            if str.hasPrefix("deck:") {
                let raw = String(str.dropFirst(5))
                if let deckID = UUID(uuidString: raw) {
                    switch overKind {
                    case .folder(let fid):
                        addDeckToFolder(deckID, fid)
                        handled = true
                    case .deck(let targetID):
                        if deckID != targetID {
                            let root = rootIDsProvider()
                            let insertAt = root.firstIndex(of: overID) ?? 0
                            createFolderFromDecks(deckID, targetID, insertAt)
                            handled = true
                        }
                    }
                }
            }
        }
        draggingID = nil
        if handled { Haptics.success() }
        return handled
    }
}

// RenameSheet is shared in components/shelf/RenameSheet.swift

enum SampleDecks {
    static let gre1 = FlashcardDeck(name: "GRE 高频詞 1", cards: [
        Flashcard(front: "# aberrant\n\n- adjective\n- departing from an accepted standard\n\nSyn: deviant", back: "中文：異常的、反常的", frontNote: nil, backNote: nil),
        Flashcard(front: "# ameliorate\n\n- verb\n- to make something better; improve\n\n**Example**: *We need to ameliorate the working conditions.*", back: "中文：改善、改進\n\n近義：improve, enhance\n反義：worsen", frontNote: nil, backNote: "備註：正式語氣，日常可用 improve"),
        Flashcard(front: "# laconic\n\n- adjective\n- using very few words", back: "中文：簡潔的、言簡意賅的", frontNote: nil, backNote: nil)
    ])

    static let toefl = FlashcardDeck(name: "TOEFL 學術字彙", cards: [
        Flashcard(front: "# hypothesis\n\n- noun\n- a supposition or proposed explanation made on the basis of limited evidence", back: "中文：假設、假說", frontNote: nil, backNote: nil),
        Flashcard(front: "# compelling\n\n- adjective\n- evoking interest, attention, or admiration", back: "中文：引人注目的；令人信服的", frontNote: nil, backNote: nil)
    ])

    static let gratitudeAndChoices = FlashcardDeck(name: "日常表達：感恩與選擇", cards: [
        Flashcard(
            front: "寫感恩日記",
            back: "(keep a gratitude diary | maintain a gratitude journal)",
            frontNote: nil,
            backNote: "備註：gratitude diary/journal 皆可"
        ),
        Flashcard(
            front: "更容易感到快樂",
            back: "(be more likely | have a higher tendency) to (be happy | feel joyful)",
            frontNote: nil,
            backNote: nil
        ),
        Flashcard(
            front: "經歷較少憂鬱症狀",
            back: "experience fewer depression symptoms",
            frontNote: nil,
            backNote: nil
        ),
        Flashcard(
            front: "辭去穩定工作",
            back: "(quit a stable job | give up a stable position)",
            frontNote: nil,
            backNote: "備註：position 偏正式；口語用 job 更自然"
        ),
        Flashcard(
            front: "創業",
            back: "(start one's own business | become an entrepreneur)",
            frontNote: nil,
            backNote: nil
        ),
        Flashcard(
            front: "證明是正確決定",
            back: "(turn out to be the right decision | prove to be the best choice)",
            frontNote: nil,
            backNote: "備註：turn out 帶有『後來結果是』語感"
        ),
        Flashcard(
            front: "做過最好的決定",
            back: "the best decision one has ever made",
            frontNote: nil,
            backNote: nil
        ),
        Flashcard(
            front: "報名才藝班",
            back: "(enroll children in skill classes | sign up for extracurricular classes)",
            frontNote: nil,
            backNote: "備註：extracurricular 指課外；skill classes 可視情境替換"
        )
    ])

    static let all: [FlashcardDeck] = [gre1, toefl, gratitudeAndChoices]
}

#Preview {
    NavigationStack { FlashcardDecksView() }
}
