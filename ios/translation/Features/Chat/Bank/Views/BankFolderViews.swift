import SwiftUI

struct BankFolderCard: View {
    let folder: BankFolder
    @Environment(\.locale) private var locale
    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(.title3)
                        .foregroundStyle(DS.Brand.scheme.stucco.opacity(0.85))
                        .frame(width: DS.IconSize.cardIcon)
                    Text(folder.name)
                        .dsType(DS.Font.serifBody)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                DSSeparator(color: DS.Palette.border.opacity(0.12))
                Text(String(format: String(localized: "bank.folder.count", locale: locale), folder.bookNames.count))
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: DS.CardSize.minHeightStandard)
        }
    }
}

struct NewBankFolderCard: View {
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

struct BankFolderDetailView: View {
    let folderID: UUID
    @ObservedObject var vm: CorrectionViewModel
    var onPracticeLocal: ((String, BankItem, String?) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var folders: BankFoldersStore
    @EnvironmentObject private var localBank: LocalBankStore
    @EnvironmentObject private var localProgress: LocalBankProgressStore
    @State private var renamingBook: LocalBankBook? = nil
    @State private var deletingBookName: String? = nil
    @State private var showDeleteConfirm: Bool = false
    @State private var error: String? = nil
    @State private var draggingBookName: String? = nil
    @State private var showRenameSheet = false
    @Environment(\.locale) private var locale

    private var folder: BankFolder? { folders.folders.first(where: { $0.id == folderID }) }

    private var booksInFolder: [LocalBankBook] {
        guard let f = folder else { return [] }
        let set = Set(f.bookNames)
        return localBank.books.filter { set.contains($0.name) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                RootDropArea(title: String(localized: "folder.root.moveOut", locale: locale)) {
                    draggingBookName = nil
                } onPerform: { payload in
                    if let name = BookDragPayload.decode(payload) {
                        folders.remove(bookName: name)
                        Haptics.success()
                        return true
                    }
                    return false
                }

                if let error { DSCard { Text(error).foregroundStyle(.secondary) } }

                let cols = [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.sm2)]
                LazyVGrid(columns: cols, spacing: DS.Spacing.sm2) {
                    ForEach(booksInFolder) { b in
                        NavigationLink {
                            let handler: ((BankItem, String?) -> Void)? = {
                                if let external = self.onPracticeLocal {
                                    return { item, tag in
                                        dismiss()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { external(b.name, item, tag) }
                                    }
                                } else {
                                    return { item, tag in
                                        vm.bindLocalBankStores(localBank: localBank, progress: localProgress)
                                        vm.startLocalPractice(bookName: b.name, item: item, tag: tag)
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { dismiss() }
                                    }
                                }
                            }()
                            LocalBankListView(vm: vm, bookName: b.name, onPractice: handler)
                        } label: {
                            let stats = localProgress.stats(book: b.name, totalItems: b.items.count)
                            ShelfTileCard(
                                title: b.name,
                                subtitle: nil,
                                countText: String(format: String(localized: "bank.book.count", locale: locale), b.items.count),
                                iconSystemName: nil,
                                accentColor: DS.Palette.primary,
                                showChevron: true,
                                progress: (stats.total > 0 ? Double(stats.done) / Double(stats.total) : 0)
                            )
                        }
                        .buttonStyle(DSCardLinkStyle())
                        .contextMenu {
                            Button(String(localized: "bank.action.moveToRoot", locale: locale)) { folders.remove(bookName: b.name) }
                            Button(String(localized: "action.rename", locale: locale)) { renamingBook = b }
                            Button(String(localized: "action.delete", locale: locale), role: .destructive) { deletingBookName = b.name; showDeleteConfirm = true }
                            #if canImport(UIKit)
                            Button(String(localized: "action.copyName", locale: locale)) { UIPasteboard.general.string = b.name }
                            #endif
                        }
                        .onDrag { draggingBookName = b.name; return BookDragPayload.provider(for: b.name) }
                    }
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
                    Button(String(localized: "action.delete", locale: locale), role: .destructive) { _ = folders.removeFolder(folderID) }
                }
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameSheet(name: folder?.name ?? "") { new in folders.rename(folderID, to: new) }
                .presentationDetents([.height(180)])
        }
        .sheet(item: $renamingBook) { book in
            RenameSheet(name: book.name) { new in
                let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed != book.name else { return }
                localBank.rename(book.name, to: trimmed)
                folders.replaceBookName(old: book.name, with: trimmed)
                localProgress.renameBook(from: book.name, to: trimmed)
            }
            .presentationDetents([.height(180)])
        }
        .confirmationDialog(String(localized: "bank.confirm.deleteBook", locale: locale), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                if let name = deletingBookName {
                    localBank.remove(name)
                    folders.remove(bookName: name)
                    localProgress.removeBook(name)
                }
                deletingBookName = nil
            }
            Button(String(localized: "action.cancel", locale: locale), role: .cancel) { deletingBookName = nil }
        }
    }
}

enum BookDragPayload {
    static func provider(for name: String) -> NSItemProvider { NSItemProvider(object: "book:\(name)" as NSString) }
    static func decode(_ s: String) -> String? {
        guard s.hasPrefix("book:") else { return nil }
        return String(s.dropFirst("book:".count))
    }
}
