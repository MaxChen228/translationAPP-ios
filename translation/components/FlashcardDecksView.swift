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
    private var cols: [GridItem] { [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.sm2)] }
    @State private var renaming: PersistedFlashcardDeck? = nil
    @State private var renamingFolder: DeckFolder? = nil
    @State private var draggingDeckID: UUID? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                DSSectionHeader(title: "單字卡集", subtitle: "選擇一個卡片集開始練習", accentUnderline: true)

                // 資料夾區
                if !deckFolders.folders.isEmpty {
                    Text("資料夾").dsType(DS.Font.section).foregroundStyle(.secondary)
                    LazyVGrid(columns: cols, spacing: DS.Spacing.sm2) {
                        ForEach(deckFolders.folders) { folder in
                            NavigationLink { DeckFolderDetailView(folderID: folder.id) } label: {
                                DeckFolderCard(folder: folder)
                            }
                            .buttonStyle(DSCardLinkStyle())
                            .contextMenu {
                                Button("重新命名") { renamingFolder = folder }
                                Button("刪除", role: .destructive) {
                                    _ = deckFolders.removeFolder(folder.id)
                                }
                            }
                            .onDrop(of: [.text], delegate: DeckIntoFolderDropDelegate(folderID: folder.id, folders: deckFolders, draggingID: $draggingDeckID))
                        }
                        // 新增資料夾
                        Button { _ = deckFolders.addFolder() } label: { NewDeckFolderCard() }
                            .buttonStyle(.plain)
                    }
                }

                // 根層單字卡區
                let rootDecks: [PersistedFlashcardDeck] = decksStore.decks.filter { !deckFolders.isInAnyFolder($0.id) }
                if !rootDecks.isEmpty {
                    if !deckFolders.folders.isEmpty { DSSeparator(color: DS.Palette.border.opacity(0.2)) }
                    Text("單字卡").dsType(DS.Font.section).foregroundStyle(.secondary)
                    LazyVGrid(columns: cols, spacing: DS.Spacing.sm2) {
                        ForEach(rootDecks) { deck in
                            DeckItemLink(deck: deck) {
                                renaming = deck
                            } onDelete: {
                                // 刪除前清理資料夾引用
                                deckFolders.remove(deckID: deck.id)
                                decksStore.remove(deck.id)
                            }
                            .onDrag { draggingDeckID = deck.id; return DeckDragPayload.provider(for: deck.id) }
                            .onDrop(of: [.text], delegate: DeckReorderDropDelegate(item: deck, store: decksStore, draggingID: $draggingDeckID))
                        }
                    }
                    .dsAnimation(DS.AnimationToken.reorder, value: decksStore.decks)
                }

                // 示例卡集：在沒有自訂卡集時提供
                if decksStore.decks.isEmpty {
                    DSSeparator(color: DS.Palette.border.opacity(0.2))
                    Text("示例")
                        .dsType(DS.Font.section)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: cols, spacing: DS.Spacing.sm2) {
                        ForEach(SampleDecks.all) { deck in
                            NavigationLink {
                                FlashcardsView(title: deck.name, cards: deck.cards)
                            } label: {
                                DeckCard(name: deck.name, count: deck.cards.count)
                            }
                            .buttonStyle(DSCardLinkStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        // 後備 drop：把項目拖到空白處或邊緣放下時清除 dragging 狀態
        .onDrop(of: [.text], delegate: ClearDragStateDropDelegate(draggingID: $draggingDeckID))
        .navigationTitle("單字卡")
        .sheet(item: $renaming) { dk in
            RenameDeckSheet(name: dk.name) { new in
                decksStore.rename(dk.id, to: new)
            }
            .presentationDetents([.height(180)])
        }
        .sheet(item: $renamingFolder) { f in
            RenameFolderSheet(name: f.name) { new in
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
        DSCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .dsType(DS.Font.section)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text("共 \(count) 張")
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: DS.IconSize.chevronSm, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Palette.border.opacity(0.18), lineWidth: DS.BorderWidth.hairline)
        )
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
                .onLongPressGesture { onRename() }
        }
        .buttonStyle(DSCardLinkStyle())
    }
}

// MARK: - Drag/Drop Helpers (root reordering, folder drop)

private struct DeckReorderDropDelegate: DropDelegate {
    let item: PersistedFlashcardDeck
    let store: FlashcardDecksStore
    @Binding var draggingID: UUID?

    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func dropEntered(info: DropInfo) {
        guard let draggingID, draggingID != item.id else { return }
        guard let from = store.index(of: draggingID), let to = store.index(of: item.id) else { return }
        if from != to {
            store.moveDeck(id: draggingID, to: to > from ? to + 1 : to)
            Haptics.lightTick()
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggingID = nil
        Haptics.success()
        return true
    }
}

private struct DeckIntoFolderDropDelegate: DropDelegate {
    let folderID: UUID
    let folders: DeckFoldersStore
    @Binding var draggingID: UUID?

    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.text])
        guard let p = providers.first else { draggingID = nil; return false }
        var handled = false
        let _ = p.loadObject(ofClass: NSString.self) { obj, _ in
            if let ns = obj as? NSString, let id = DeckDragPayload.decodeDeckID(ns as String) {
                Task { @MainActor in folders.add(deckID: id, to: folderID); Haptics.success() }
                handled = true
            }
        }
        draggingID = nil
        return handled
    }
}

private struct ClearDragStateDropDelegate: DropDelegate {
    @Binding var draggingID: UUID?
    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { draggingID = nil; return true }
}

private struct RenameDeckSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    let onDone: (String) -> Void
    init(name: String, onDone: @escaping (String) -> Void) {
        self._text = State(initialValue: name)
        self.onDone = onDone
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("重新命名").dsType(DS.Font.section)
            TextField("名稱", text: $text)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("完成") {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { onDone(trimmed) }
                    dismiss()
                }
                .buttonStyle(DSPrimaryButton())
                .frame(width: 120)
            }
        }
        .padding(16)
        .background(DS.Palette.background)
    }
}

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
