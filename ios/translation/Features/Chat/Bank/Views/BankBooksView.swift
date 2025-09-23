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
    @StateObject private var editController = ShelfEditController<String>()
    @EnvironmentObject private var bankFolders: BankFoldersStore
    @EnvironmentObject private var bankOrder: BankBooksOrderStore
    @EnvironmentObject private var localBank: LocalBankStore
    @EnvironmentObject private var localProgress: LocalBankProgressStore
    @EnvironmentObject private var randomSettings: RandomPracticeStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    @State private var renamingFolder: BankFolder? = nil
    @State private var renamingBook: LocalBankBook? = nil
    @State private var deletingBookName: String? = nil
    @State private var showDeleteConfirm: Bool = false
    @State private var showRandomSettings: Bool = false
    @State private var folderPendingDelete: BankFolder? = nil
    @State private var folderDeleteMessageText: String = ""
    @State private var showFolderDeleteConfirm: Bool = false
    @State private var showBulkDeleteConfirm: Bool = false
    @Environment(\.locale) private var locale

    private var selectedCount: Int { editController.selectedIDs.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // 移除頂部大標題，避免與下方區塊重複
                if let error {
                    ErrorStateCard(title: error)
                }
                // 資料夾區：即使為 0 也顯示新增卡
                let folderCols = [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.sm2)]
                ShelfGrid(titleKey: "bank.folders.title", columns: folderCols) {
                    ForEach(bankFolders.folders) { folder in
                        NavigationLink { BankFolderDetailView(folderID: folder.id, vm: vm, onPracticeLocal: onPracticeLocal) } label: {
                            let countText = String(format: String(localized: "bank.folder.count", locale: locale), folder.bookNames.count)
                            ShelfTileCard(title: folder.name, subtitle: nil, countText: countText, iconSystemName: "folder", accentColor: DS.Brand.scheme.stucco, showChevron: true)
                        }
                        .buttonStyle(DSCardLinkStyle())
                        .contextMenu {
                            Button(String(localized: "action.edit", locale: locale)) {
                                editController.enterEditMode()
                                Haptics.medium()
                            }
                            Button(String(localized: "action.rename", locale: locale)) { renamingFolder = folder }
                            Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                                editController.exitEditMode()
                                prepareFolderDeletion(folder)
                            }
                        }
                        .onDrop(of: [.text], delegate: BookIntoFolderDropDelegate(folderID: folder.id, folders: bankFolders, editController: editController))
                        .simultaneousGesture(
                            editController.isEditing ?
                            TapGesture().onEnded {
                                editController.exitEditMode()
                            } : nil
                        )
                    }
                    Button { _ = bankFolders.addFolder(name: String(localized: "folder.new", locale: locale)) } label: { NewBankFolderCard() }
                        .buttonStyle(.plain)
                }
                DSSeparator(color: DS.Palette.border.opacity(0.2))

                // 根層本機書本（未分到資料夾）＋自訂順序
                let localRootBooks = localBank.books.filter { !bankFolders.isInAnyFolder($0.name) }
                let rootNames = localRootBooks.map { $0.name }
                let orderedNames = bankOrder.currentRootOrder(root: rootNames)
                let orderedRootBooks: [LocalBankBook] = orderedNames.compactMap { nm in localRootBooks.first(where: { $0.name == nm }) }
                let cols = [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.sm2)]
                VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
                    DSSectionHeader(titleKey: "bank.local.title", accentUnderline: true)
                        .overlay(alignment: .topTrailing) {
                            HStack(spacing: DS.Spacing.sm) {
                                NavigationLink {
                                    AllBankItemsView(vm: vm, onPractice: onPracticeLocal)
                                } label: {
                                    DSQuickActionIconGlyph(systemName: "list.bullet", shape: .circle, size: 28)
                                }
                                .accessibilityLabel("瀏覽所有題庫")
                                RandomPracticeToolbarButton { runRandomPractice() }
                                RandomSettingsToolbarButton {
                                    editController.exitEditMode()
                                    showRandomSettings = true
                                }
                            }
                            .padding(.top, 2)
                        }
                    LazyVGrid(columns: cols, spacing: DS.Spacing.sm2) {
                        // 瀏覽雲端精選（複製到本機）
                                NavigationLink { CloudCourseLibraryView(vm: vm) } label: {
                                    BrowseCloudCard(titleKey: "bank.browseCloud")
                                }
                        .buttonStyle(.plain)
                        .disabled(editController.isEditing)
                        ForEach(orderedRootBooks) { b in
                            let isEditing = editController.isEditing
                            let isSelected = editController.isSelected(b.name)
                            let stats = localProgress.stats(book: b.name, totalItems: b.items.count)
                            let card = ShelfTileCard(
                                title: b.name,
                                subtitle: nil,
                                countText: String(format: String(localized: "bank.book.count", locale: locale), b.items.count),
                                iconSystemName: nil,
                                accentColor: DS.Palette.primary,
                                showChevron: true,
                                progress: (stats.total > 0 ? Double(stats.done) / Double(stats.total) : 0)
                            )
                            .shelfSelectable(isEditing: isEditing, isSelected: isSelected)

                            Group {
                                if isEditing {
                                    card
                                        .contentShape(RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous))
                                        .highPriorityGesture(
                                            TapGesture().onEnded {
                                                editController.toggleSelection(b.name)
                                            }
                                        )
                                        .contextMenu {
                                            Button(String(localized: "bank.action.moveToRoot", locale: locale)) { bankFolders.remove(bookName: b.name) }
                                            Button(String(localized: "action.rename", locale: locale)) { renamingBook = b }
                                            Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                                                deletingBookName = b.name
                                                showDeleteConfirm = true
                                            }
                                        }
                                } else {
                                    NavigationLink {
                                        LocalBankListView(vm: vm, bookName: b.name, onPractice: practiceHandler(for: b))
                                    } label: {
                                        card
                                    }
                                    .buttonStyle(DSCardLinkStyle())
                                    .contextMenu {
                                        Button(String(localized: "action.edit", locale: locale)) {
                                            editController.enterEditMode()
                                            Haptics.medium()
                                        }
                                        Button(String(localized: "action.rename", locale: locale)) {
                                            editController.exitEditMode()
                                            renamingBook = b
                                        }
                                        Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                                            editController.exitEditMode()
                                            deletingBookName = b.name
                                            showDeleteConfirm = true
                                        }
                                    }
                                }
                            }
                            .shelfWiggle(isActive: isEditing)
                            .shelfConditionalDrag(isEditing) {
                                editController.beginDragging(b.name)
                                let payload = ShelfDragPayload(
                                    primaryID: b.name,
                                    selectedIDs: orderedSelection(anchor: b.name, ordered: orderedRootBooks.map { $0.name })
                                )
                                return NSItemProvider(object: payload.encodedString() as NSString)
                            }
                            .onDrop(of: [.text], delegate: BankRootReorderDropDelegate(
                                bookName: b.name,
                                editController: editController,
                                orderedNames: orderedRootBooks.map { $0.name },
                                bankOrder: bankOrder
                            ))
                        .highPriorityGesture(
                            TapGesture().onEnded {
                                if isEditing {
                                    editController.toggleSelection(b.name)
                                }
                            }
                        )
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        if editController.isEditing, selectedCount > 0 {
                            BankBulkToolbar(count: selectedCount) {
                                showBulkDeleteConfirm = true
                            }
                            .padding(.top, DS.Spacing.sm)
                        }
                    }
                }
                .dsAnimation(DS.AnimationToken.reorder, value: bankOrder.order)
                if localBank.books.isEmpty && error == nil {
                    EmptyStateCard(
                        title: String(localized: "bank.local.empty", locale: locale),
                        subtitle: String(localized: "cloud.books.subtitle", locale: locale),
                        iconSystemName: "books.vertical"
                    )
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        .navigationTitle(Text("nav.bank"))
        .onDrop(of: [.text], delegate: ClearBookDragStateDropDelegate(editController: editController))
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded {
                if editController.isEditing {
                    editController.exitEditMode()
                }
            },
            including: .gesture
        )
        .onAppear {
            AppLog.uiInfo("[books] appear (local)=\(localBank.books.count)")
            editController.exitEditMode()
        }
        .sheet(isPresented: $showRandomSettings) {
            RandomPracticeSettingsSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $renamingFolder) { f in
            RenameSheet(name: f.name) { new in bankFolders.rename(f.id, to: new) }
                .presentationDetents([.height(180)])
        }
        .confirmationDialog(
            String(localized: "bank.confirm.deleteFolder.title", locale: locale),
            isPresented: $showFolderDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                if let folder = folderPendingDelete {
                    deleteFolder(folder)
                }
            }
            Button(String(localized: "action.cancel", locale: locale), role: .cancel) {
                cancelFolderDeletion()
            }
        } message: {
            Text(folderDeleteMessageText)
        }
        .sheet(item: $renamingBook) { book in
            RenameSheet(name: book.name) { new in
                let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed != book.name else { return }
                localBank.rename(book.name, to: trimmed)
                bankFolders.replaceBookName(old: book.name, with: trimmed)
                localProgress.renameBook(from: book.name, to: trimmed)
            }
            .presentationDetents([.height(180)])
        }
        .confirmationDialog(String(localized: "bank.confirm.deleteBook", locale: locale), isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                if let name = deletingBookName {
                    localBank.remove(name)
                    bankFolders.remove(bookName: name)
                    localProgress.removeBook(name)
                }
                deletingBookName = nil
            }
            Button(String(localized: "action.cancel", locale: locale), role: .cancel) { deletingBookName = nil }
        }
        .confirmationDialog(String(localized: "bank.bulkDelete.confirm", defaultValue: "Delete selected books?"), isPresented: $showBulkDeleteConfirm, titleVisibility: .visible) {
            Button(String(localized: "action.deleteAll", defaultValue: "Delete All"), role: .destructive) {
                deleteSelectedBooks()
                showBulkDeleteConfirm = false
            }
            Button(String(localized: "action.cancel", locale: locale), role: .cancel) {
                showBulkDeleteConfirm = false
            }
        }
    }

    private func orderedSelection(anchor: String, ordered: [String]) -> [String] {
        let selected = editController.selectedIDs
        guard selected.contains(anchor), !selected.isEmpty else { return [anchor] }
        let orderedMatch = ordered.filter { selected.contains($0) }
        return orderedMatch.isEmpty ? [anchor] : orderedMatch
    }

    private func deleteSelectedBooks() {
        let names = editController.selectedIDs
        guard !names.isEmpty else { return }
        for name in names {
            localBank.remove(name)
            bankFolders.remove(bookName: name)
            localProgress.removeBook(name)
            bankOrder.removeFromRoot(name)
        }
        editController.clearSelection()
    }

    private func practiceHandler(for book: LocalBankBook) -> ((BankItem, String?) -> Void)? {
        if let external = onPracticeLocal {
            return { item, tag in
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    external(book.name, item, tag)
                }
            }
        } else {
            return { item, tag in
                vm.bindLocalBankStores(localBank: localBank, progress: localProgress)
                vm.startLocalPractice(bookName: book.name, item: item, tag: tag)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { dismiss() }
            }
        }
    }

    // MARK: - Random helpers
    private func runRandomPractice() {
        editController.exitEditMode()
        if let picked = pickRandomItem() {
            let (bookName, item) = picked
            let tag = item.tags?.first
            if let external = onPracticeLocal {
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    external(bookName, item, tag)
                }
            } else {
                vm.bindLocalBankStores(localBank: localBank, progress: localProgress)
                vm.startLocalPractice(bookName: bookName, item: item, tag: tag)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { dismiss() }
            }
        } else {
            bannerCenter.show(title: String(localized: "banner.random.noneEligible", locale: locale))
        }
    }

    private func pickRandomItem() -> (String, BankItem)? {
        let filterState = randomSettings.filterState
        let selectedDifficulties = randomSettings.selectedDifficulties

        var pool: [(String, BankItem)] = []
        for book in localBank.books {
            for item in book.items {
                if !selectedDifficulties.isEmpty && !selectedDifficulties.contains(item.difficulty) {
                    continue
                }
                if randomSettings.excludeCompleted && localProgress.isCompleted(book: book.name, itemId: item.id) {
                    continue
                }
                if filterState.hasActiveFilters {
                    guard let tags = item.tags, !tags.isEmpty else { continue }
                    guard filterState.matches(tags: tags) else { continue }
                }
                pool.append((book.name, item))
            }
        }

        return pool.randomElement()
    }
}

private extension BankBooksView {
    func prepareFolderDeletion(_ folder: BankFolder) {
        folderPendingDelete = folder
        folderDeleteMessageText = folderDeleteMessage(for: folder)
        showFolderDeleteConfirm = true
    }

    func cancelFolderDeletion() {
        folderPendingDelete = nil
        folderDeleteMessageText = ""
        showFolderDeleteConfirm = false
    }

    func deleteFolder(_ folder: BankFolder) {
        bankFolders.deleteFolder(folder.id, cascadeWith: localBank, progress: localProgress, order: bankOrder)
        cancelFolderDeletion()
    }

    func folderDeleteMessage(for folder: BankFolder) -> String {
        String.localizedStringWithFormat(
            String(localized: "bank.confirm.deleteFolder.message", locale: locale),
            folder.bookNames.count
        )
    }
}

// MARK: - Drag/Drop helpers

private struct BookIntoFolderDropDelegate: DropDelegate {
    let folderID: UUID
    let folders: BankFoldersStore
    let editController: ShelfEditController<String>

    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.text])
        guard let p = providers.first else { editController.endDragging(); return false }
        var handled = false
        _ = p.loadObject(ofClass: NSString.self) { obj, _ in
            if let ns = obj as? NSString {
                let payload = ShelfDragPayload.decode(from: ns as String)
                let names = payload.selectedIDs.isEmpty ? [payload.primaryID] : payload.selectedIDs
                guard !names.isEmpty else { return }
                Task { @MainActor in
                    for name in names {
                        folders.add(bookName: name, to: folderID)
                    }
                    editController.clearSelection()
                    Haptics.success()
                }
                handled = true
            }
        }
        editController.endDragging()
        return handled
    }
}

private struct ClearBookDragStateDropDelegate: DropDelegate {
    let editController: ShelfEditController<String>
    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        editController.endDragging()
        return true
    }
}

private struct BankRootReorderDropDelegate: DropDelegate {
    let bookName: String
    let editController: ShelfEditController<String>
    let orderedNames: [String]
    let bankOrder: BankBooksOrderStore

    func validateDrop(info: DropInfo) -> Bool { editController.isEditing }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func dropEntered(info: DropInfo) {
        guard editController.isEditing, let dragging = editController.draggingID else { return }
        let selection = orderedSelection(anchor: dragging)
        guard !selection.contains(bookName) else { return }
        bankOrder.moveInRoot(ids: selection, before: bookName, root: orderedNames)
        Haptics.lightTick()
    }

    func performDrop(info: DropInfo) -> Bool {
        guard editController.isEditing else { return false }
        editController.endDragging()
        Haptics.success()
        return true
    }

    private func orderedSelection(anchor: String) -> [String] {
        let selected = editController.selectedIDs
        guard selected.contains(anchor), !selected.isEmpty else { return [anchor] }
        let ordered = orderedNames.filter { selected.contains($0) }
        return ordered.isEmpty ? [anchor] : ordered
    }
}

private struct BankBulkToolbar: View {
    var count: Int
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Button(action: onDelete) {
                Label(String(localized: "action.deleteAll", defaultValue: "Delete All"), systemImage: "trash")
            }
            .buttonStyle(DSButton(style: .secondary, size: .compact))

            Text(String(format: String(localized: "bulk.selectionCount", defaultValue: "已選 %d 項"), count))
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)
        }
        .background(Color.clear)
    }
}

// 遠端題庫型別已移除

private struct BrowseCloudCard: View {
    var titleKey: LocalizedStringKey
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "icloud.and.arrow.down").font(.title3)
            Text(titleKey).dsType(DS.Font.caption).foregroundStyle(.secondary)
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
