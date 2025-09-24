import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct BankFolderGridSection: View {
    @ObservedObject var vm: CorrectionViewModel
    @ObservedObject var coordinator: BankBooksCoordinator
    @ObservedObject var editController: ShelfEditController<String>
    let onPracticeLocal: ((String, BankItem, String?) -> Void)?

    @EnvironmentObject private var bankFolders: BankFoldersStore
    @Environment(\.locale) private var locale

    var body: some View {
        let folderCols = [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.sm2)]
        ShelfGrid(titleKey: "bank.folders.title", columns: folderCols) {
            ForEach(bankFolders.folders) { folder in
                NavigationLink {
                    BankFolderDetailView(folderID: folder.id, vm: vm, onPracticeLocal: onPracticeLocal)
                } label: {
                    let countText = String(
                        format: String(localized: "bank.folder.count", locale: locale),
                        folder.bookNames.count
                    )
                    ShelfTileCard(
                        title: folder.name,
                        subtitle: nil,
                        countText: countText,
                        iconSystemName: "folder",
                        accentColor: DS.Brand.scheme.stucco,
                        showChevron: true
                    )
                }
                .buttonStyle(DSCardLinkStyle())
                .contextMenu {
                    Button(String(localized: "action.edit", locale: locale)) {
                        editController.enterEditMode()
                        Haptics.medium()
                    }
                    Button(String(localized: "action.rename", locale: locale)) {
                        coordinator.renamingFolder = folder
                    }
                    Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                        editController.exitEditMode()
                        coordinator.prepareFolderDeletion(folder, locale: locale)
                    }
                }
                .onDrop(
                    of: [.text],
                    delegate: BookIntoFolderDropDelegate(
                        folderID: folder.id,
                        folders: bankFolders,
                        editController: editController
                    )
                )
                .simultaneousGesture(
                    editController.isEditing ?
                        TapGesture().onEnded { editController.exitEditMode() } : nil
                )
            }
            Button {
                _ = bankFolders.addFolder(name: String(localized: "folder.new", locale: locale))
            } label: {
                NewBankFolderCard()
            }
            .buttonStyle(.plain)
        }
    }
}

struct BankRootBooksSection: View {
    @ObservedObject var vm: CorrectionViewModel
    @ObservedObject var coordinator: BankBooksCoordinator
    @ObservedObject var editController: ShelfEditController<String>
    let onPracticeLocal: ((String, BankItem, String?) -> Void)?
    let selectedCount: Int
    let runRandomPractice: () -> Void
    let showRandomSettings: () -> Void
    let onRequestBulkDelete: () -> Void
    let errorMessage: String?

    @EnvironmentObject private var bankFolders: BankFoldersStore
    @EnvironmentObject private var bankOrder: BankBooksOrderStore
    @EnvironmentObject private var localBank: LocalBankStore
    @EnvironmentObject private var localProgress: LocalBankProgressStore
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let localRootBooks = localBank.books.filter { !bankFolders.isInAnyFolder($0.name) }
        let rootNames = localRootBooks.map { $0.name }
        let orderedNames = bankOrder.currentRootOrder(root: rootNames)
        let orderedRootBooks: [LocalBankBook] = orderedNames.compactMap { name in
            localRootBooks.first(where: { $0.name == name })
        }
        let columns = [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.sm2)]

        VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
            DSSectionHeader(titleKey: "bank.local.title", accentUnderline: true)
                .overlay(alignment: .topTrailing) {
                    VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                        HStack(spacing: DS.Spacing.sm) {
                            NavigationLink {
                                AllBankItemsView(vm: vm, onPractice: onPracticeLocal)
                            } label: {
                                DSQuickActionIconGlyph(systemName: "list.bullet", shape: .circle, size: 28)
                            }
                            .accessibilityLabel("瀏覽所有題庫")

                            RandomPracticeToolbarButton {
                                runRandomPractice()
                            }
                            RandomSettingsToolbarButton {
                                editController.exitEditMode()
                                showRandomSettings()
                            }
                        }
                        .padding(.top, 2)

                        if editController.isEditing, selectedCount > 0 {
                            BankBulkToolbar(count: selectedCount, onDelete: onRequestBulkDelete)
                        }
                    }
                }

            LazyVGrid(columns: columns, spacing: DS.Spacing.sm2) {
                NavigationLink {
                    CloudCourseLibraryView(vm: vm)
                } label: {
                    BankBrowseCloudCard(titleKey: "bank.browseCloud")
                }
                .buttonStyle(.plain)
                .disabled(editController.isEditing)

                ForEach(orderedRootBooks) { book in
                    let isEditing = editController.isEditing
                    let isSelected = editController.isSelected(book.name)
                    let stats = localProgress.stats(book: book.name, totalItems: book.items.count)
                    let card = ShelfTileCard(
                        title: book.name,
                        subtitle: nil,
                        countText: String(
                            format: String(localized: "bank.book.count", locale: locale),
                            book.items.count
                        ),
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
                                        editController.toggleSelection(book.name)
                                    }
                                )
                                .contextMenu {
                                    Button(String(localized: "bank.action.moveToRoot", locale: locale)) {
                                        bankFolders.remove(bookName: book.name)
                                    }
                                    Button(String(localized: "action.rename", locale: locale)) {
                                        coordinator.renamingBook = book
                                    }
                                    Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                                        coordinator.requestBookDeletion(named: book.name)
                                    }
                                }
                        } else {
                            let practiceHandler = coordinator.makePracticeHandler(
                                for: book,
                                onDismiss: { dismiss() },
                                externalHandler: onPracticeLocal
                            )
                            NavigationLink {
                                LocalBankListView(
                                    vm: vm,
                                    bookName: book.name,
                                    onPractice: practiceHandler
                                )
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
                                    coordinator.renamingBook = book
                                }
                                Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                                    editController.exitEditMode()
                                    coordinator.requestBookDeletion(named: book.name)
                                }
                            }
                        }
                    }
                    .shelfWiggle(isActive: isEditing)
                    .shelfConditionalDrag(isEditing) {
                        editController.beginDragging(book.name)
                        let payload = ShelfDragPayload(
                            primaryID: book.name,
                            selectedIDs: orderedSelection(anchor: book.name, ordered: orderedRootBooks.map { $0.name })
                        )
                        return NSItemProvider(object: payload.encodedString() as NSString)
                    }
                    .onDrop(
                        of: [.text],
                        delegate: BankRootReorderDropDelegate(
                            bookName: book.name,
                            editController: editController,
                            orderedNames: orderedRootBooks.map { $0.name },
                            bankOrder: bankOrder
                        )
                    )
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            if isEditing {
                                editController.toggleSelection(book.name)
                            }
                        }
                    )
                }
            }
        }
        .dsAnimation(DS.AnimationToken.reorder, value: bankOrder.order)
        if localBank.books.isEmpty && errorMessage == nil {
            EmptyStateCard(
                title: String(localized: "bank.local.empty", locale: locale),
                subtitle: String(localized: "cloud.books.subtitle", locale: locale),
                iconSystemName: "books.vertical"
            )
        }
    }

    private func orderedSelection(anchor: String, ordered: [String]) -> [String] {
        let selected = editController.selectedIDs
        guard selected.contains(anchor), !selected.isEmpty else { return [anchor] }
        let orderedMatch = ordered.filter { selected.contains($0) }
        return orderedMatch.isEmpty ? [anchor] : orderedMatch
    }
}

struct BankBulkToolbar: View {
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

struct BankBrowseCloudCard: View {
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

struct BookIntoFolderDropDelegate: DropDelegate {
    let folderID: UUID
    let folders: BankFoldersStore
    let editController: ShelfEditController<String>

    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        let providers = info.itemProviders(for: [.text])
        guard let provider = providers.first else { editController.endDragging(); return false }
        var handled = false
        _ = provider.loadObject(ofClass: NSString.self) { obj, _ in
            if let string = obj as? NSString {
                let payload = ShelfDragPayload.decode(from: string as String)
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

struct ClearBookDragStateDropDelegate: DropDelegate {
    let editController: ShelfEditController<String>
    func validateDrop(info: DropInfo) -> Bool { true }
    func dropUpdated(info: DropInfo) -> DropProposal { DropProposal(operation: .move) }
    func performDrop(info: DropInfo) -> Bool {
        editController.endDragging()
        return true
    }
}

struct BankRootReorderDropDelegate: DropDelegate {
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
