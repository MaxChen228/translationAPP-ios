import Foundation
import Testing
@testable import translation

@MainActor
@Suite("LocalBankProgressStore")
struct LocalBankProgressStoreTests {
    private let defaultsKey = "local.bank.progress"

    private func withIsolatedDefaults<T>(_ body: () throws -> T) rethrows -> T {
        let defaults = UserDefaults.standard
        let previous = defaults.object(forKey: defaultsKey)
        defaults.removeObject(forKey: defaultsKey)
        defer {
            if let data = previous as? Data {
                defaults.set(data, forKey: defaultsKey)
            } else if let previous {
                defaults.set(previous, forKey: defaultsKey)
            } else {
                defaults.removeObject(forKey: defaultsKey)
            }
        }
        return try body()
    }

    @Test("markCompleted 更新完成狀態與次數")
    func markCompletedUpdatesState() throws {
        try withIsolatedDefaults {
            let store = LocalBankProgressStore()
            store.markCompleted(book: "Book A", itemId: "item-1", score: 80)

            #expect(store.isCompleted(book: "Book A", itemId: "item-1"))
            #expect(store.attempts(book: "Book A", itemId: "item-1") == 1)

            store.markCompleted(book: "Book A", itemId: "item-1", score: 90)
            #expect(store.attempts(book: "Book A", itemId: "item-1") == 2)

            let stats = store.stats(book: "Book A", totalItems: 5)
            #expect(stats.done == 1)
            #expect(stats.total == 5)
        }
    }

    @Test("renameBook 會搬移完成紀錄")
    func renameBookMovesRecords() throws {
        try withIsolatedDefaults {
            let store = LocalBankProgressStore()
            store.markCompleted(book: "Old Book", itemId: "item-1", score: 75)

            store.renameBook(from: "Old Book", to: "New Book")

            #expect(!store.isCompleted(book: "Old Book", itemId: "item-1"))
            #expect(store.isCompleted(book: "New Book", itemId: "item-1"))
            #expect(store.attempts(book: "New Book", itemId: "item-1") == 1)
        }
    }

    @Test("removeBook 會清除指定書籍紀錄")
    func removeBookClearsRecords() throws {
        try withIsolatedDefaults {
            let store = LocalBankProgressStore()
            store.markCompleted(book: "Book B", itemId: "item-2", score: 60)

            store.removeBook("Book B")

            #expect(!store.isCompleted(book: "Book B", itemId: "item-2"))
            #expect(store.attempts(book: "Book B", itemId: "item-2") == 0)
        }
    }

    @Test("初始化時會恢復既有進度")
    func persistenceRoundtripRestoresState() throws {
        try withIsolatedDefaults {
            let store = LocalBankProgressStore()
            store.markCompleted(book: "Book Persist", itemId: "item-3", score: 85)

            let reloaded = LocalBankProgressStore()

            #expect(reloaded.isCompleted(book: "Book Persist", itemId: "item-3"))
            #expect(reloaded.attempts(book: "Book Persist", itemId: "item-3") == 1)
        }
    }
}

