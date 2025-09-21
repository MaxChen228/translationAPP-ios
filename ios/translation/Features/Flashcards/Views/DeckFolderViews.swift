import SwiftUI

// MARK: - Folder Cards (Grid Item)

struct DeckFolderCard: View {
    let folder: DeckFolder
    @Environment(\.locale) private var locale
    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSCardTitle(
                    icon: "folder",
                    titleText: folder.name,
                    accentColor: DS.Brand.scheme.monument
                )
                DSSeparator(color: DS.Palette.border.opacity(0.12))
                Text(String(format: String(localized: "folder.decks.count", locale: locale), folder.deckIDs.count))
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: DS.CardSize.minHeightStandard)
        }
    }
}

struct NewDeckFolderCard: View {
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder.badge.plus").font(.title3)
            Text("folder.new").dsType(DS.Font.caption).foregroundStyle(.secondary)
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

// MARK: - Folder Detail

struct DeckFolderDetailView: View {
    let folderID: UUID
    @EnvironmentObject private var folders: DeckFoldersStore
    @EnvironmentObject private var decksStore: FlashcardDecksStore

    @State private var draggingDeckID: UUID? = nil
    @State private var showRenameSheet: Bool = false
    @Environment(\.locale) private var locale

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
                RootDropArea(title: String(localized: "folder.root.moveOut", locale: locale)) {
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
                            Text(String(localized: "deck.folder.empty", locale: locale)).dsType(DS.Font.bodyEmph)
                            Text(String(localized: "deck.folder.hint", locale: locale))
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
        .navigationTitle(folder?.name ?? String(localized: "nav.folder", locale: locale))
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button(String(localized: "action.rename", locale: locale)) { showRenameSheet = true }
                    Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                        _ = folders.removeFolder(folderID)
                    }
                }
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameSheet(name: folder?.name ?? "") { new in
                folders.rename(folderID, to: new)
            }
            .presentationDetents([.height(180)])
        }
    }
}

private struct FolderDeckCard: View {
    let name: String
    let count: Int
    @Environment(\.locale) private var locale
    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(name)
                    .dsType(DS.Font.section)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                HStack(spacing: 8) {
                    Text(String(format: String(localized: "deck.cards.count", locale: locale), count))
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

// MARK: - Rename Sheet moved to components/shelf/RenameSheet.swift

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
                if let ns = obj as? NSString { _ = onPerform(ns as String) }
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
