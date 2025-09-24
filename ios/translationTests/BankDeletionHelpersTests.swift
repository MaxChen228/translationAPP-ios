import Foundation
import Testing
@testable import translation

@MainActor
@Suite("Bank Deletion Helpers")
struct BankDeletionHelpersTests {
    private let defaultsKeys = [
        "local.bank.books",
        "bank.folders",
        "local.bank.progress",
        "bank.books.order"
    ]

    private var sampleItem: BankItem {
        BankItem(
            id: "item-1",
            zh: "中文題目",
            hints: [],
            suggestions: []
        )
    }

    private func withIsolatedDefaults<T>(_ body: () throws -> T) rethrows -> T {
        let defaults = UserDefaults.standard
        let previous = defaultsKeys.map { ($0, defaults.object(forKey: $0)) }
        defaultsKeys.forEach { defaults.removeObject(forKey: $0) }
        defer {
            for (key, value) in previous {
                if let data = value as? Data {
                    defaults.set(data, forKey: key)
                } else if let value {
                    defaults.set(value, forKey: key)
                } else {
                    defaults.removeObject(forKey: key)
                }
            }
        }
        return try body()
    }

    @Test("deleteBooks 會將題庫從所有 store 清除")
    func cascadeDeleteRemovesBookEverywhere() throws {
        try withIsolatedDefaults {
            let localBank = LocalBankStore()
            let folders = BankFoldersStore()
            let progress = LocalBankProgressStore()
            let order = BankBooksOrderStore()

            localBank.addOrReplaceBook(name: "Test Book", items: [sampleItem])
            let folder = folders.addFolder(name: "Folder")
            folders.add(bookName: "Test Book", to: folder.id)
            progress.markCompleted(book: "Test Book", itemId: sampleItem.id, score: 90)
            order.ensure(names: ["Test Book"])

            BankCascadeDeletionService.deleteBooks(
                ["Test Book"],
                localBank: localBank,
                folders: folders,
                progress: progress,
                order: order
            )

            #expect(localBank.books.contains(where: { $0.name == "Test Book" }) == false)
            #expect(folders.isInAnyFolder("Test Book") == false)
            #expect(progress.isCompleted(book: "Test Book", itemId: sampleItem.id) == false)
            #expect(order.order.contains("Test Book") == false)
        }
    }

    @Test("deleteFolder 會透過 BankCascadeDeletionService 清掉所有資料")
    func deleteFolderCascades() throws {
        try withIsolatedDefaults {
            let localBank = LocalBankStore()
            let folders = BankFoldersStore()
            let progress = LocalBankProgressStore()
            let order = BankBooksOrderStore()

            localBank.addOrReplaceBook(name: "Book A", items: [sampleItem])
            localBank.addOrReplaceBook(name: "Book B", items: [sampleItem])
            let folder = folders.addFolder(name: "Folder")
            folders.add(bookName: "Book A", to: folder.id)
            folders.add(bookName: "Book B", to: folder.id)
            progress.markCompleted(book: "Book A", itemId: sampleItem.id, score: 82)
            progress.markCompleted(book: "Book B", itemId: sampleItem.id, score: 78)
            order.ensure(names: ["Book A", "Book B"])

            folders.deleteFolder(
                folder.id,
                cascadeWith: localBank,
                progress: progress,
                order: order
            )

            #expect(folders.folders.contains(where: { $0.id == folder.id }) == false)
            #expect(localBank.books.isEmpty)
            #expect(progress.isCompleted(book: "Book A", itemId: sampleItem.id) == false)
            #expect(progress.isCompleted(book: "Book B", itemId: sampleItem.id) == false)
            #expect(order.order.isEmpty)
        }
    }

    @Test("資料夾刪除訊息會帶入書本數量")
    func deleteMessageContainsCount() {
        let message = BankDeletionMessageBuilder.folderDeleteMessage(
            bookCount: 3,
            locale: Locale(identifier: "en")
        )
        #expect(message.contains("3"))
    }
}
