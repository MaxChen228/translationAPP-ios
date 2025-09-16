import SwiftUI

// MARK: - Folder Cards (Grid Item)

struct DeckFolderCard: View {
    let folder: DeckFolder
    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(.title3)
                        .foregroundStyle(DS.Brand.scheme.monument.opacity(0.85))
                        .frame(width: 28)
                    Text(folder.name)
                        .dsType(DS.Font.serifBody)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                DSSeparator(color: DS.Palette.border.opacity(0.12))
                Text("共 \(folder.deckIDs.count) 個")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 104)
        }
    }
}

struct NewDeckFolderCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.plus").font(.title3)
            Text("新資料夾").dsType(DS.Font.caption).foregroundStyle(.secondary)
        }
        .frame(minHeight: 96)
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

// MARK: - Folder Detail

struct DeckFolderDetailView: View {
    let folderID: UUID
    @EnvironmentObject private var folders: DeckFoldersStore
    @EnvironmentObject private var decksStore: FlashcardDecksStore

    @State private var draggingDeckID: UUID? = nil
    @State private var showRenameSheet: Bool = false

    private var folder: DeckFolder? { folders.folders.first(where: { $0.id == folderID }) }

    private var decksInFolder: [PersistedFlashcardDeck] {
        guard let f = folder else { return [] }
        let dict = Dictionary(uniqueKeysWithValues: decksStore.decks.map { ($0.id, $0) })
        return f.deckIDs.compactMap { dict[$0] }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // Drop zone to move out to root
                RootDropArea(title: "拖曳到此移出到根") {
                    draggingDeckID = nil
                } onPerform: { payload in
                    if let deckID = DeckDragPayload.decodeDeckID(payload) {
                        folders.remove(deckID: deckID)
                        Haptics.success()
                        return true
                    }
                    return false
                }

                if decksInFolder.isEmpty {
                    DSCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("資料夾內尚無單字卡集").dsType(DS.Font.bodyEmph)
                            Text("從根清單拖曳卡片到此資料夾即可收納。")
                                .dsType(DS.Font.caption).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    let cols = [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.sm2)]
                    LazyVGrid(columns: cols, spacing: DS.Spacing.sm2) {
                        ForEach(decksInFolder) { deck in
                            NavigationLink {
                                DeckDetailView(deckID: deck.id)
                            } label: {
                                FolderDeckCard(name: deck.name, count: deck.cards.count)
                            }
                            .buttonStyle(DSCardLinkStyle())
                            .onDrag { draggingDeckID = deck.id; return DeckDragPayload.provider(for: deck.id) }
                        }
                    }
                    .dsAnimation(DS.AnimationToken.reorder, value: folders.folders)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        .navigationTitle(folder?.name ?? "資料夾")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button("重新命名") { showRenameSheet = true }
                    Button("刪除", role: .destructive) {
                        _ = folders.removeFolder(folderID)
                    }
                }
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameFolderSheet(name: folder?.name ?? "") { new in
                folders.rename(folderID, to: new)
            }
            .presentationDetents([.height(180)])
        }
    }
}

private struct FolderDeckCard: View {
    let name: String
    let count: Int
    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .dsType(DS.Font.section)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
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
    }
}

// MARK: - Rename Folder Sheet

struct RenameFolderSheet: View {
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

// MARK: - Root Drop Area (Move out)

struct RootDropArea: View {
    var title: String
    var onEnter: () -> Void
    var onPerform: (String) -> Bool

    @State private var isTargeted: Bool = false

    var body: some View {
        VStack {
            Text(title)
                .dsType(DS.Font.caption)
                .foregroundStyle(isTargeted ? DS.Palette.primary : .secondary)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .stroke(DS.Palette.primary.opacity(isTargeted ? DS.Opacity.strong : DS.Opacity.border), lineWidth: DS.BorderWidth.regular)
                )
        }
        .onDrop(of: [.text], isTargeted: $isTargeted) { providers in
            _ = onEnter()
            guard let p = providers.first else { return false }
            _ = p.loadObject(ofClass: NSString.self) { obj, _ in
                if let s = obj as String? { _ = onPerform(s) }
            }
            return true
        }
    }
}

// MARK: - Drag Payload Helper

enum DeckDragPayload {
    static func provider(for id: UUID) -> NSItemProvider {
        return NSItemProvider(object: "deck:\(id.uuidString)" as NSString)
    }
    static func decodeDeckID(_ s: String) -> UUID? {
        guard s.hasPrefix("deck:") else { return nil }
        let raw = String(s.dropFirst("deck:".count))
        return UUID(uuidString: raw)
    }
}
