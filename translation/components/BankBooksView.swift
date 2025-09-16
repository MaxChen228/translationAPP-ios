import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct BankBooksView: View {
    @ObservedObject var vm: CorrectionViewModel
    // When provided, pressing "練習" in a list will call this instead of writing into `vm`.
    // Typical use: create a new workspace and route to it from the home quick action.
    var onPractice: ((BankItem, String?) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var books: [BankService.BankBook] = []
    @State private var isLoading = false
    @State private var error: String? = nil
    @State private var isImporting = false
    @State private var importMessage: String? = nil
    @State private var showImportAlert: Bool = false
    private let service = BankService()
    @EnvironmentObject private var bankFolders: BankFoldersStore
    @EnvironmentObject private var bankOrder: BankBooksOrderStore
    @State private var renamingFolder: BankFolder? = nil
    @State private var draggingBookName: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                DSSectionHeader(
                    title: "題庫本",
                    subtitle: "選擇一個書本開始練習",
                    accentUnderline: true
                )
                if let error {
                    DSCard {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text(error)
                                .dsType(DS.Font.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if isLoading {
                    placeholderCard
                } else if books.isEmpty {
                    DSCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("目前沒有題庫本")
                                .dsType(DS.Font.bodyEmph)
                            Text("下拉以重新整理，或稍後再試。")
                                .dsType(DS.Font.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    // 資料夾區
                    if !bankFolders.folders.isEmpty {
                        let cols = [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.sm2)]
                        ShelfGrid(title: "資料夾", columns: cols) {
                            ForEach(bankFolders.folders) { folder in
                                NavigationLink { BankFolderDetailView(folderID: folder.id) } label: {
                                    ShelfTileCard(title: folder.name, subtitle: nil, countText: "共 \(folder.bookNames.count) 本", iconSystemName: "folder", accentColor: DS.Brand.scheme.stucco, showChevron: true)
                                }
                                .buttonStyle(DSCardLinkStyle())
                                .contextMenu {
                                    Button("重新命名") { renamingFolder = folder }
                                    Button("刪除", role: .destructive) { _ = bankFolders.removeFolder(folder.id) }
                                }
                                .onDrop(of: [.text], delegate: BookIntoFolderDropDelegate(folderID: folder.id, folders: bankFolders, draggingName: $draggingBookName))
                            }
                            Button { _ = bankFolders.addFolder() } label: { NewBankFolderCard() }
                                .buttonStyle(.plain)
                        }
                        DSSeparator(color: DS.Palette.border.opacity(0.2))
                    }

                    // 根層書本（未分到資料夾）＋ 依自訂順序排序
                    let rootBooks = books.filter { !bankFolders.isInAnyFolder($0.name) }
                    let rootNames = rootBooks.map { $0.name }
                    let orderedNames = bankOrder.currentRootOrder(root: rootNames)
                    let orderedRootBooks: [BankService.BankBook] = orderedNames.compactMap { nm in rootBooks.first(where: { $0.name == nm }) }
                    let cols = [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.sm2)]
                    ShelfGrid(title: "題庫本", columns: cols) {
                        ForEach(orderedRootBooks) { book in
                            NavigationLink {
                                BankListView(vm: vm, tag: book.name, onPractice: { item, tag in
                                    if let onPractice { onPractice(item, tag) }
                                    dismiss()
                                })
                            } label: {
                                ShelfTileCard(
                                    title: book.name.capitalized,
                                    subtitle: "難度 \(book.difficultyMin)-\(book.difficultyMax)",
                                    countText: "共 \(book.count) 題",
                                    iconSystemName: nil,
                                    accentColor: DS.Palette.primary,
                                    showChevron: true
                                )
                            }
                            .buttonStyle(DSCardLinkStyle())
                            .contextMenu {
                                if bankFolders.folders.isEmpty {
                                    Text("尚無資料夾").foregroundStyle(.secondary)
                                } else {
                                    ForEach(bankFolders.folders) { folder in
                                        Button("加入 \(folder.name)") { bankFolders.add(bookName: book.name, to: folder.id) }
                                    }
                                }
                                #if canImport(UIKit)
                                Button("複製名稱") { UIPasteboard.general.string = book.name }
                                #endif
                            }
                            .onDrag { draggingBookName = book.name; return BookDragPayload.provider(for: book.name) }
                            .onDrop(of: [.text], delegate: ShelfReorderDropDelegate(
                                overItemID: book.name,
                                draggingID: $draggingBookName,
                                indexOf: { name in bankOrder.indexInRoot(name, root: orderedRootBooks.map { $0.name }) },
                                move: { id, to in bankOrder.moveInRoot(id: id, to: to, root: orderedRootBooks.map { $0.name }) }
                            ))
                        }
                    }
                    .dsAnimation(DS.AnimationToken.reorder, value: bankOrder.order)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        .navigationTitle("題庫本")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    Button { _ = bankFolders.addFolder() } label: { Label("新資料夾", systemImage: "folder.badge.plus") }
                    Button { Task { await importFromClipboard() } } label: { Label("匯入", systemImage: "doc.on.clipboard") }
                        .disabled(isLoading || isImporting)
                }
            }
        }
        .onDrop(of: [.text], delegate: ClearBookDragStateDropDelegate(draggingName: $draggingBookName))
        .task { await load() }
        .refreshable { await load() }
        .onAppear { AppLog.uiInfo("[books] appear count=\(books.count)") }
        .alert(importMessage ?? "", isPresented: $showImportAlert) {
            Button("好") { showImportAlert = false; importMessage = nil }
        }
        .sheet(item: $renamingFolder) { f in
            RenameSheet(name: f.name) { new in bankFolders.rename(f.id, to: new) }
                .presentationDetents([.height(180)])
        }
    }

    private var placeholderCard: some View {
        let cols = [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.sm2)]
        return LazyVGrid(columns: cols, spacing: DS.Spacing.sm2) {
            ForEach(0..<4, id: \.self) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous).fill(DS.Palette.border.opacity(0.35)).frame(width: 100, height: 16)
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous).fill(DS.Palette.border.opacity(0.25)).frame(width: 60, height: 12)
                        RoundedRectangle(cornerRadius: DS.Radius.xs, style: .continuous).fill(DS.Palette.border.opacity(0.25)).frame(width: 90, height: 12)
                        Spacer(minLength: 0)
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
        }
        .redacted(reason: .placeholder)
    }

    private func load() async {
        isLoading = true
        error = nil
        do { books = try await service.fetchBooks() } catch { self.error = (error as NSError).localizedDescription }
        isLoading = false
    }

    private func importFromClipboard() async {
        #if os(iOS)
        guard let raw = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            importMessage = "剪貼簿沒有可匯入的文字"
            showImportAlert = true
            return
        }
        #else
        let raw = ""
        #endif
        isImporting = true
        defer { isImporting = false }
        do {
            let result = try await service.importClipboard(text: raw, defaultTag: nil, replace: false)
            await MainActor.run {
                importMessage = "已匯入 \(result.imported) 題"
                showImportAlert = true
            }
            await load()
        } catch {
            await MainActor.run {
                importMessage = (error as NSError).localizedDescription
                showImportAlert = true
            }
        }
    }
}

// MARK: - Drag/Drop helpers

private struct BookIntoFolderDropDelegate: DropDelegate {
    let folderID: UUID
    let folders: BankFoldersStore
    @Binding var draggingName: String?

    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.text])
        guard let p = providers.first else { draggingName = nil; return false }
        var handled = false
        _ = p.loadObject(ofClass: NSString.self) { obj, _ in
            if let ns = obj as? NSString, let name = BookDragPayload.decode(ns as String) {
                Task { @MainActor in folders.add(bookName: name, to: folderID); Haptics.success() }
                handled = true
            }
        }
        draggingName = nil
        return handled
    }
}

private struct ClearBookDragStateDropDelegate: DropDelegate {
    @Binding var draggingName: String?
    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool { draggingName = nil; return true }
}

private struct BankBookRow: View {
    let book: BankService.BankBook
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(book.name.capitalized)
                    .dsType(DS.Font.section)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    Text("共 \(book.count) 題")
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)

                    TagLabel(text: "難度 \(book.difficultyMin)-\(book.difficultyMax)", color: DS.Palette.primary)
                }
            }

            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: DS.IconSize.chevronMd, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(DS.Palette.surface)
    }
}

private struct BankBookCard: View {
    let book: BankService.BankBook
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(book.name.capitalized)
                .dsType(DS.Font.section)
                .foregroundStyle(.primary)

            HStack(spacing: 8) {
                Text("共 \(book.count) 題")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)

                TagLabel(text: "難度 \(book.difficultyMin)-\(book.difficultyMax)", color: DS.Palette.primary)

                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: DS.IconSize.chevronSm, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(DS.Spacing.md2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DS.Palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Palette.border.opacity(0.3), lineWidth: DS.BorderWidth.hairline)
        )
        .dsCardShadow()
    }
}
