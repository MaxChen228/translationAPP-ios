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
    @EnvironmentObject private var folders: BankFoldersStore
    private let service = BankService()

    @State private var books: [BankService.BankBook] = []
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var draggingBookName: String? = nil
    @State private var showRenameSheet = false

    private var folder: BankFolder? { folders.folders.first(where: { $0.id == folderID }) }

    private var booksInFolder: [BankService.BankBook] {
        guard let f = folder else { return [] }
        let set = Set(f.bookNames)
        return books.filter { set.contains($0.name) }
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
                    ForEach(booksInFolder) { book in
                        NavigationLink { BankListView(vm: CorrectionViewModel(), tag: book.name) } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(book.name.capitalized)
                                    .dsType(DS.Font.section)
                                    .foregroundStyle(.primary)
                                HStack(spacing: 8) {
                                    Text("共 \(book.count) 題").dsType(DS.Font.caption).foregroundStyle(.secondary)
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").foregroundStyle(.tertiary)
                                }
                            }
                            .padding(DS.Spacing.md2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(DS.Palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                    .stroke(DS.Palette.border.opacity(0.3), lineWidth: DS.BorderWidth.hairline)
                            )
                        }
                        .buttonStyle(DSCardLinkStyle())
                        .onDrag { draggingBookName = book.name; return BookDragPayload.provider(for: book.name) }
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
            RenameFolderSheet(name: folder?.name ?? "") { new in folders.rename(folderID, to: new) }
                .presentationDetents([.height(180)])
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        isLoading = true
        error = nil
        do { books = try await service.fetchBooks() } catch { self.error = (error as NSError).localizedDescription }
        isLoading = false
    }
}

enum BookDragPayload {
    static func provider(for name: String) -> NSItemProvider { NSItemProvider(object: "book:\(name)" as NSString) }
    static func decode(_ s: String) -> String? {
        guard s.hasPrefix("book:") else { return nil }
        return String(s.dropFirst("book:".count))
    }
}

