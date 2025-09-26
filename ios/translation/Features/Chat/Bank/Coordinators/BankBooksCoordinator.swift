import Foundation
import SwiftUI

@MainActor
final class BankBooksCoordinator: ObservableObject {
    private(set) weak var viewModel: CorrectionViewModel?
    private(set) var foldersStore: BankFoldersStore?
    private(set) var orderStore: BankBooksOrderStore?
    private(set) var localBankStore: LocalBankStore?
    private(set) var progressStore: LocalBankProgressStore?
    private(set) var randomSettingsStore: RandomPracticeStore?
    private(set) var bannerCenter: BannerCenter?

    @Published var folderPendingDelete: BankFolder?
    @Published var folderDeleteMessageText: String = ""
    @Published var showFolderDeleteConfirm: Bool = false

    @Published var renamingFolder: BankFolder?
    @Published var renamingBook: LocalBankBook?

    @Published var deletingBookName: String?
    @Published var showDeleteConfirm: Bool = false
    @Published var showBulkDeleteConfirm: Bool = false

    @Published private(set) var isReady: Bool = false

    private var isConfigured = false

    func configure(
        viewModel: CorrectionViewModel,
        foldersStore: BankFoldersStore,
        orderStore: BankBooksOrderStore,
        localBankStore: LocalBankStore,
        progressStore: LocalBankProgressStore,
        randomSettingsStore: RandomPracticeStore,
        bannerCenter: BannerCenter
    ) {
        guard !isConfigured else { return }
        self.viewModel = viewModel
        self.foldersStore = foldersStore
        self.orderStore = orderStore
        self.localBankStore = localBankStore
        self.progressStore = progressStore
        self.randomSettingsStore = randomSettingsStore
        self.bannerCenter = bannerCenter
        isReady = true
        isConfigured = true
    }

    // MARK: - Folder deletion
    func prepareFolderDeletion(_ folder: BankFolder, locale: Locale) {
        folderPendingDelete = folder
        folderDeleteMessageText = BankDeletionMessageBuilder.folderDeleteMessage(
            bookCount: folder.bookNames.count,
            locale: locale
        )
        showFolderDeleteConfirm = true
    }

    func cancelFolderDeletion() {
        folderPendingDelete = nil
        folderDeleteMessageText = ""
        showFolderDeleteConfirm = false
    }

    func confirmFolderDeletion() {
        guard let folder = folderPendingDelete else { return }
        deleteFolder(folder)
        cancelFolderDeletion()
    }

    private func deleteFolder(_ folder: BankFolder) {
        guard
            let foldersStore,
            let localBankStore,
            let progressStore,
            let orderStore
        else { return }
        foldersStore.deleteFolder(
            folder.id,
            cascadeWith: localBankStore,
            progress: progressStore,
            order: orderStore
        )
    }

    // MARK: - Book deletion
    func requestBookDeletion(named name: String) {
        deletingBookName = name
        showDeleteConfirm = true
    }

    func cancelBookDeletion() {
        deletingBookName = nil
        showDeleteConfirm = false
    }

    func confirmBookDeletion() {
        guard let name = deletingBookName else { return }
        deleteBooks([name])
        cancelBookDeletion()
    }

    func deleteBooks(_ names: [String]) {
        guard
            let localBankStore,
            let foldersStore,
            let progressStore,
            let orderStore
        else { return }
        BankCascadeDeletionService.deleteBooks(
            names,
            localBank: localBankStore,
            folders: foldersStore,
            progress: progressStore,
            order: orderStore
        )
    }

    func toggleBulkDeleteConfirmation(_ shouldShow: Bool) {
        showBulkDeleteConfirm = shouldShow
    }

    // MARK: - Practice helpers
    func makePracticeHandler(
        for book: LocalBankBook,
        onDismiss: @escaping () -> Void,
        externalHandler: ((String, BankItem, String?) -> Void)?
    ) -> ((BankItem, String?) -> Void)? {
        guard let viewModel, let localBankStore, let progressStore else {
            return nil
        }
        if let externalHandler {
            return { item, tag in
                onDismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    externalHandler(book.name, item, tag)
                }
            }
        } else {
            return { [weak viewModel] item, tag in
                guard let viewModel else { return }
                viewModel.bindLocalBankStores(localBank: localBankStore, progress: progressStore)
                viewModel.startLocalPractice(bookName: book.name, item: item, tag: tag)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { onDismiss() }
            }
        }
    }

    func runRandomPractice(
        locale: Locale,
        onDismiss: @escaping () -> Void,
        externalHandler: ((String, BankItem, String?) -> Void)?
    ) {
        guard let pick = pickRandomItem() else {
            bannerCenter?.show(title: String(localized: "banner.random.noneEligible", locale: locale))
            return
        }
        let (bookName, item) = pick
        let tag = item.tags?.first
        if let externalHandler {
            onDismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                externalHandler(bookName, item, tag)
            }
        } else {
            guard let viewModel, let localBankStore, let progressStore else { return }
            viewModel.bindLocalBankStores(localBank: localBankStore, progress: progressStore)
            viewModel.startLocalPractice(bookName: bookName, item: item, tag: tag)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { onDismiss() }
        }
    }

    private func pickRandomItem() -> (String, BankItem)? {
        guard let randomSettingsStore, let localBankStore, let progressStore else { return nil }
        let filterState = randomSettingsStore.filterState
        let selectedDifficulties = randomSettingsStore.selectedDifficulties

        let availableNames = Set(localBankStore.books.map { $0.name })
        let normalizedScope = randomSettingsStore.normalizedBookScope(with: availableNames)
        let allowedNames = normalizedScope.isEmpty ? availableNames : normalizedScope
        guard !allowedNames.isEmpty else { return nil }

        var pool: [(String, BankItem)] = []
        for book in localBankStore.books where allowedNames.contains(book.name) {
            for item in book.items {
                if !selectedDifficulties.isEmpty && !selectedDifficulties.contains(item.difficulty) {
                    continue
                }
                if randomSettingsStore.excludeCompleted && progressStore.isCompleted(book: book.name, itemId: item.id) {
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
