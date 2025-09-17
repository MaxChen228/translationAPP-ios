import SwiftUI

struct BankFolderCard: View {
    let folder: BankFolder
    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                HStack(spacing: 10) {
                    Image(systemName: "folder")
                        .font(.title3)
                        .foregroundStyle(DS.Brand.scheme.stucco.opacity(0.85))
                        .frame(width: 28)
                    Text(folder.name)
                        .dsType(DS.Font.serifBody)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                DSSeparator(color: DS.Palette.border.opacity(0.12))
                Text("共 \(folder.bookNames.count) 本")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 104)
        }
    }
}

struct NewBankFolderCard: View {
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

struct BankFolderDetailView: View {
    let folderID: UUID
    @ObservedObject var vm: CorrectionViewModel
    var onPracticeLocal: ((String, BankItem, String?) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var folders: BankFoldersStore
    @EnvironmentObject private var localBank: LocalBankStore
    @EnvironmentObject private var localProgress: LocalBankProgressStore
    @State private var error: String? = nil
    @State private var draggingBookName: String? = nil
    @State private var showRenameSheet = false

    private var folder: BankFolder? { folders.folders.first(where: { $0.id == folderID }) }

    private var booksInFolder: [LocalBankBook] {
        guard let f = folder else { return [] }
        let set = Set(f.bookNames)
        return localBank.books.filter { set.contains($0.name) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                RootDropArea(title: "拖曳到此移出到根") {
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
                                countText: "共 \\(b.items.count) 題",
                                iconSystemName: nil,
                                accentColor: DS.Palette.primary,
                                showChevron: true,
                                progress: (stats.total > 0 ? Double(stats.done) / Double(stats.total) : 0)
                            )
                        }
                        .buttonStyle(DSCardLinkStyle())
                        .contextMenu {
                            Button("移出到根") { folders.remove(bookName: b.name) }
                            #if canImport(UIKit)
                            Button("複製名稱") { UIPasteboard.general.string = b.name }
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
        .navigationTitle(folder?.name ?? "資料夾")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack {
                    Button("重新命名") { showRenameSheet = true }
                    Button("刪除", role: .destructive) { _ = folders.removeFolder(folderID) }
                }
            }
        }
        .sheet(isPresented: $showRenameSheet) {
            RenameSheet(name: folder?.name ?? "") { new in folders.rename(folderID, to: new) }
                .presentationDetents([.height(180)])
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
