import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct BankBooksView: View {
    @ObservedObject var vm: CorrectionViewModel
    // Home-level entry can provide a handler to create a new Workspace and route to it.
    // We pass along the bookName so caller can start local practice properly.
    var onPracticeLocal: ((String, BankItem, String?) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var error: String? = nil
    @EnvironmentObject private var bankFolders: BankFoldersStore
    @EnvironmentObject private var bankOrder: BankBooksOrderStore
    @EnvironmentObject private var localBank: LocalBankStore
    @EnvironmentObject private var localProgress: LocalBankProgressStore
    @State private var renamingFolder: BankFolder? = nil
    @State private var draggingBookName: String? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // 移除頂部大標題，避免與下方區塊重複
                if let error {
                    ErrorStateCard(title: error)
                }
                // 資料夾區：即使為 0 也顯示新增卡
                let folderCols = [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.sm2)]
                ShelfGrid(title: "資料夾", columns: folderCols) {
                    ForEach(bankFolders.folders) { folder in
                        NavigationLink { BankFolderDetailView(folderID: folder.id, vm: vm, onPracticeLocal: onPracticeLocal) } label: {
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

                // 根層本機書本（未分到資料夾）＋自訂順序
                let localRootBooks = localBank.books.filter { !bankFolders.isInAnyFolder($0.name) }
                let rootNames = localRootBooks.map { $0.name }
                let orderedNames = bankOrder.currentRootOrder(root: rootNames)
                let orderedRootBooks: [LocalBankBook] = orderedNames.compactMap { nm in localRootBooks.first(where: { $0.name == nm }) }
                let cols = [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.sm2)]
                ShelfGrid(title: "題庫本", columns: cols) {
                    // 瀏覽雲端精選（複製到本機）
                    NavigationLink { CloudBankLibraryView(vm: vm) } label: {
                        BrowseCloudCard(title: "瀏覽雲端題庫")
                    }
                    .buttonStyle(.plain)
                    ForEach(orderedRootBooks) { b in
                        NavigationLink {
                            // Workspace 內：直接寫入當前 vm 並返回；首頁快捷入口：交由外部建立 Workspace
                            let handler: ((BankItem, String?) -> Void)? = {
                                if let external = self.onPracticeLocal {
                                    return { item, tag in
                                        dismiss()
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                            external(b.name, item, tag)
                                        }
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
                                countText: "共 \(b.items.count) 題",
                                iconSystemName: nil,
                                accentColor: DS.Palette.primary,
                                showChevron: true,
                                progress: (stats.total > 0 ? Double(stats.done) / Double(stats.total) : 0)
                            )
                        }
                        .buttonStyle(DSCardLinkStyle())
                        .contextMenu {
                            if bankFolders.folders.isEmpty {
                                Text("尚無資料夾").foregroundStyle(.secondary)
                            } else {
                                ForEach(bankFolders.folders) { folder in
                                    Button("加入 \(folder.name)") { bankFolders.add(bookName: b.name, to: folder.id) }
                                }
                            }
                            #if canImport(UIKit)
                            Button("複製名稱") { UIPasteboard.general.string = b.name }
                            #endif
                        }
                        .onDrag { draggingBookName = b.name; return BookDragPayload.provider(for: b.name) }
                        .onDrop(of: [.text], delegate: ShelfReorderDropDelegate(
                            overItemID: b.name,
                            draggingID: $draggingBookName,
                            indexOf: { name in bankOrder.indexInRoot(name, root: orderedRootBooks.map { $0.name }) },
                            move: { id, to in bankOrder.moveInRoot(id: id, to: to, root: orderedRootBooks.map { $0.name }) }
                        ))
                    }
                }
                .dsAnimation(DS.AnimationToken.reorder, value: bankOrder.order)
                if localBank.books.isEmpty && error == nil {
                    EmptyStateCard(
                        title: "目前沒有題庫本",
                        subtitle: "先從雲端瀏覽複製一些題目到本機。",
                        iconSystemName: "books.vertical"
                    )
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        .navigationTitle("題庫本")
        .onDrop(of: [.text], delegate: ClearBookDragStateDropDelegate(draggingName: $draggingBookName))
        .onAppear { AppLog.uiInfo("[books] appear (local)=\(localBank.books.count)") }
        .sheet(item: $renamingFolder) { f in
            RenameSheet(name: f.name) { new in bankFolders.rename(f.id, to: new) }
                .presentationDetents([.height(180)])
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

// 遠端題庫型別已移除

private struct BrowseCloudCard: View {
    var title: String
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "icloud.and.arrow.down").font(.title3)
            Text(title).dsType(DS.Font.caption).foregroundStyle(.secondary)
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
