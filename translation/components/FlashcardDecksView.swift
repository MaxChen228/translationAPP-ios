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

    // Overlay drag state
    @StateObject private var dragState = DragState()
    @State private var tileFrames: [String: CGRect] = [:]
    private let coordName = "deckGridSpace"

    var body: some View {
        // Compose IDs
        let rootDecks: [PersistedFlashcardDeck] = decksStore.decks.filter { !deckFolders.isInAnyFolder($0.id) }
        let folderIDs = deckFolders.folders.map { "folder:\($0.id.uuidString)" }
        let deckIDs = rootDecks.map { "deck:\($0.id.uuidString)" }
        let rootIDs = folderIDs + deckIDs
        let orderedIDs = deckOrder.currentOrder(rootIDs: rootIDs)

        return DragLayer(state: dragState) {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    Text("單字卡集")
                        .dsType(DS.Font.section)
                        .fontWeight(.semibold)
                    Text("選擇一個卡片集開始練習")
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)

                    ShelfGrid(columns: cols) {
                        ForEach(orderedIDs, id: \.self) { tid in
                            if tid.hasPrefix("folder:"), let fid = UUID(uuidString: String(tid.dropFirst(7))), let folder = deckFolders.folders.first(where: { $0.id == fid }) {
                                AnyView(
                                    NavigationLink { DeckFolderDetailView(folderID: folder.id) } label: {
                                        ShelfTileCard(title: folder.name, subtitle: nil, countText: "共 \(folder.deckIDs.count) 個", iconSystemName: "folder", accentColor: DS.Brand.scheme.monument, showChevron: true)
                                    }
                                    .reportTileFrame(id: "folder:\(folder.id.uuidString)", in: .named(coordName))
                                    .buttonStyle(DSCardLinkStyle())
                                    .contextMenu {
                                        Button("重新命名") { renamingFolder = folder }
                                        Button("刪除", role: .destructive) { _ = deckFolders.removeFolder(folder.id); deckOrder.removeFromOrder("folder:\(folder.id.uuidString)") }
                                    }
                                )
                            } else if tid.hasPrefix("deck:"), let did = UUID(uuidString: String(tid.dropFirst(5))), let deck = rootDecks.first(where: { $0.id == did }) {
                                AnyView(
                                    NavigationLink { DeckDetailView(deckID: deck.id) } label: {
                                        ShelfTileCard(title: deck.name, subtitle: nil, countText: "共 \(deck.cards.count) 張", iconSystemName: nil, accentColor: DS.Palette.primary, showChevron: true)
                                    }
                                    .reportTileFrame(id: "deck:\(deck.id.uuidString)", in: .named(coordName))
                                    .buttonStyle(DSCardLinkStyle())
                                    .contextMenu {
                                        Button("重新命名") { renaming = deck }
                                        Button("刪除", role: .destructive) {
                                            decksStore.remove(deck.id)
                                            deckOrder.removeFromOrder("deck:\(deck.id.uuidString)")
                                        }
                                    }
                                    .highPriorityGesture(deckDragGesture(for: deck))
                                )
                            }
                        }
                    }

                    // Add folder tile
                    ShelfGrid(columns: cols) {
                        Button { _ = deckFolders.addFolder() } label: { NewDeckFolderCard() }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
            }
        }
        .background(DS.Palette.background)
        .navigationTitle("單字卡")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { _ = deckFolders.addFolder() } label: { Label("新資料夾", systemImage: "folder.badge.plus") } } }
        .sheet(item: $renaming) { dk in
            RenameSheet(name: dk.name) { new in decksStore.rename(dk.id, to: new) }
                .presentationDetents([.height(180)])
        }
        .sheet(item: $renamingFolder) { f in
            RenameSheet(name: f.name) { new in deckFolders.rename(f.id, to: new) }
                .presentationDetents([.height(180)])
        }
        .coordinateSpace(name: coordName)
        .onPreferenceChange(TileFrameKey.self) { frames in self.tileFrames = frames }
        .onChange(of: dragState.location) { _ in handleDragMove() }
    }

    // MARK: - Drag logic
    private func deckDragGesture(for deck: PersistedFlashcardDeck) -> some Gesture {
        let key = "deck:\(deck.id.uuidString)"
        let longPress = LongPressGesture(minimumDuration: 0.5)
            .onEnded { _ in
                let frame = tileFrames[key] ?? .zero
                withAnimation(DS.AnimationToken.snappy) {
                    dragState.isDragging = true
                    dragState.itemID = .deck(deck.id)
                    dragState.preview = DragPreview(
                        view: AnyView(ShelfTileCard(title: deck.name, subtitle: nil, countText: "共 \(deck.cards.count) 張", iconSystemName: nil, accentColor: DS.Palette.primary, showChevron: false)
                            .shadow(radius: 8).opacity(0.98)),
                        size: CGSize(width: max(1, frame.width), height: max(1, frame.height))
                    )
                    dragState.location = CGPoint(x: frame.midX, y: frame.midY)
                }
                Haptics.lightTick()
            }
        let drag = DragGesture(minimumDistance: 1)
            .onChanged { v in
                let base = tileFrames[key] ?? .zero
                dragState.location = CGPoint(x: base.minX + v.location.x, y: base.minY + v.location.y)
            }
            .onEnded { _ in
                finalizeDrop(at: dragState.location)
                withAnimation(DS.AnimationToken.subtle) { dragState.reset() }
            }
        return longPress.sequenced(before: drag)
    }

    private func handleDragMove() {
        guard dragState.isDragging, case .deck(let did)? = dragState.itemID else { return }
        let rootDecks: [PersistedFlashcardDeck] = decksStore.decks.filter { !deckFolders.isInAnyFolder($0.id) }
        let rootIDs = rootDecks.map { "deck:\($0.id.uuidString)" }
        let loc = dragState.location
        var nearestKey: String? = nil
        var best: CGFloat = .infinity
        for (key, frame) in tileFrames where key.hasPrefix("deck:") {
            let d = hypot(CGFloat(frame.midX - loc.x), CGFloat(frame.midY - loc.y))
            if d < best { best = d; nearestKey = key }
        }
        guard let targetKey = nearestKey else { return }
        let currentKey = "deck:\(did.uuidString)"
        if let cur = rootIDs.firstIndex(of: currentKey), let tgt = rootIDs.firstIndex(of: targetKey), cur != tgt {
            let folderIDs = deckFolders.folders.map { "folder:\($0.id.uuidString)" }
            deckOrder.move(id: currentKey, to: tgt, rootIDs: folderIDs + rootIDs)
        }
    }

    private func finalizeDrop(at point: CGPoint) {
        guard let item = dragState.itemID else { return }
        for (key, frame) in tileFrames where key.hasPrefix("folder:") {
            if frame.contains(point), case .deck(let did) = item, let fid = UUID(uuidString: String(key.dropFirst(7))) {
                deckFolders.add(deckID: did, to: fid)
                deckOrder.removeFromOrder("deck:\(did.uuidString)")
                Haptics.success()
                return
            }
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
        NavigationLink { DeckDetailView(deckID: deck.id) } label: {
            DeckCard(name: deck.name, count: deck.cards.count)
                .contextMenu {
                    Button("重新命名") { onRename() }
                    Button("刪除", role: .destructive) { onDelete() }
                }
        }
        .buttonStyle(DSCardLinkStyle())
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

#Preview { NavigationStack { FlashcardDecksView() } }
