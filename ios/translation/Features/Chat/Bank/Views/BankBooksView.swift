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
    @StateObject private var coordinator = BankBooksCoordinator()
    @State private var showRandomSettings: Bool = false
    @Environment(\.locale) private var locale

    private var selectedCount: Int { editController.selectedIDs.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                // 移除頂部大標題，避免與下方區塊重複
                if let error {
                    ErrorStateCard(title: error)
                }
                BankFolderGridSection(
                    vm: vm,
                    coordinator: coordinator,
                    editController: editController,
                    onPracticeLocal: onPracticeLocal
                )

                DSSeparator(color: DS.Palette.border.opacity(0.2))

                BankRootBooksSection(
                    vm: vm,
                    coordinator: coordinator,
                    editController: editController,
                    onPracticeLocal: onPracticeLocal,
                    selectedCount: selectedCount,
                    runRandomPractice: runRandomPractice,
                    showRandomSettings: { showRandomSettings = true },
                    onRequestBulkDelete: { coordinator.toggleBulkDeleteConfirmation(true) },
                    errorMessage: error
                )
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        .navigationTitle(Text("nav.bank"))
        .onDrop(of: [.text], delegate: ClearBookDragStateDropDelegate(editController: editController))
        .contentShape(Rectangle())
        .gesture(
            TapGesture().onEnded {
                if editController.isEditing {
                    editController.exitEditMode()
                }
            },
            including: .gesture
        )
        .onAppear {
            configureCoordinatorIfNeeded()
            AppLog.uiInfo("[books] appear (local)=\(localBank.books.count)")
            editController.exitEditMode()
        }
        .sheet(isPresented: $showRandomSettings) {
            RandomPracticeSettingsSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(item: Binding(
            get: { coordinator.renamingFolder },
            set: { coordinator.renamingFolder = $0 }
        )) { folder in
            RenameSheet(name: folder.name) { new in bankFolders.rename(folder.id, to: new) }
                .presentationDetents([.height(180)])
        }
        .confirmationDialog(
            String(localized: "bank.confirm.deleteFolder.title", locale: locale),
            isPresented: Binding(
                get: { coordinator.showFolderDeleteConfirm },
                set: { newValue in
                    coordinator.showFolderDeleteConfirm = newValue
                    if !newValue { coordinator.cancelFolderDeletion() }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                coordinator.confirmFolderDeletion()
            }
            Button(String(localized: "action.cancel", locale: locale), role: .cancel) {
                coordinator.cancelFolderDeletion()
            }
        } message: {
            Text(coordinator.folderDeleteMessageText)
        }
        .sheet(item: Binding(
            get: { coordinator.renamingBook },
            set: { coordinator.renamingBook = $0 }
        )) { book in
            RenameSheet(name: book.name) { new in
                let trimmed = new.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, trimmed != book.name else { return }
                localBank.rename(book.name, to: trimmed)
                bankFolders.replaceBookName(old: book.name, with: trimmed)
                localProgress.renameBook(from: book.name, to: trimmed)
            }
            .presentationDetents([.height(180)])
        }
        .confirmationDialog(
            String(localized: "bank.confirm.deleteBook", locale: locale),
            isPresented: Binding(
                get: { coordinator.showDeleteConfirm },
                set: { newValue in
                    coordinator.showDeleteConfirm = newValue
                    if !newValue { coordinator.cancelBookDeletion() }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "action.delete", locale: locale), role: .destructive) {
                coordinator.confirmBookDeletion()
            }
            Button(String(localized: "action.cancel", locale: locale), role: .cancel) {
                coordinator.cancelBookDeletion()
            }
        }
        .confirmationDialog(
            String(localized: "bank.bulkDelete.confirm", defaultValue: "Delete selected books?"),
            isPresented: Binding(
                get: { coordinator.showBulkDeleteConfirm },
                set: { newValue in
                    coordinator.showBulkDeleteConfirm = newValue
                    if !newValue { coordinator.toggleBulkDeleteConfirmation(false) }
                }
            ),
            titleVisibility: .visible
        ) {
            Button(String(localized: "action.deleteAll", defaultValue: "Delete All"), role: .destructive) {
                deleteSelectedBooks()
                coordinator.toggleBulkDeleteConfirmation(false)
            }
            Button(String(localized: "action.cancel", locale: locale), role: .cancel) {
                coordinator.toggleBulkDeleteConfirmation(false)
            }
        }
    }

    private func configureCoordinatorIfNeeded() {
        coordinator.configure(
            viewModel: vm,
            foldersStore: bankFolders,
            orderStore: bankOrder,
            localBankStore: localBank,
            progressStore: localProgress,
            randomSettingsStore: randomSettings,
            bannerCenter: bannerCenter
        )
    }

    private func deleteSelectedBooks() {
        let names = editController.selectedIDs
        guard !names.isEmpty else { return }
        coordinator.deleteBooks(Array(names))
        editController.clearSelection()
    }

    // MARK: - Random helpers
    private func runRandomPractice() {
        editController.exitEditMode()
        coordinator.runRandomPractice(
            locale: locale,
            onDismiss: { dismiss() },
            externalHandler: onPracticeLocal
        )
    }

}
