import Foundation
import Testing
@testable import translation

@MainActor
@Suite("LocalBankStore")
struct LocalBankStoreTests {
    private let defaultsKey = "local.bank.books"

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

    private func makeItem(id: String = UUID().uuidString, text: String = "題目") -> BankItem {
        BankItem(
            id: id,
            zh: text,
            hints: [],
            suggestions: [],
            suggestion: nil,
            tags: nil,
            difficulty: 1,
            completed: nil
        )
    }

    @Test("addOrReplaceBook 建立與覆寫題庫")
    func addOrReplaceBookUpdatesCollection() throws {
        try withIsolatedDefaults {
            let store = LocalBankStore()
            let firstItem = makeItem(id: "item-1", text: "第一題")
            store.addOrReplaceBook(name: "Book A", items: [firstItem])

            #expect(store.items(in: "Book A") == [firstItem])
            #expect(store.books.first?.name == "Book A")

            let secondItem = makeItem(id: "item-2", text: "第二題")
            store.addOrReplaceBook(name: "Book A", items: [secondItem])

            #expect(store.items(in: "Book A") == [secondItem])
            #expect(store.books.count == 1)
        }
    }

    @Test("rename 調整題庫名稱並保留項目")
    func renameBookKeepsItems() throws {
        try withIsolatedDefaults {
            let store = LocalBankStore()
            let item = makeItem(id: "item-3", text: "第三題")
            store.addOrReplaceBook(name: "Old Name", items: [item])

            store.rename("Old Name", to: "New Name")

            #expect(store.items(in: "Old Name").isEmpty)
            #expect(store.items(in: "New Name") == [item])
            #expect(store.books.first?.name == "New Name")
        }
    }

    @Test("remove 刪除指定題庫")
    func removeBookClearsEntry() throws {
        try withIsolatedDefaults {
            let store = LocalBankStore()
            store.addOrReplaceBook(name: "Book B", items: [makeItem(id: "item-4")])

            store.remove("Book B")

            #expect(store.items(in: "Book B").isEmpty)
            #expect(store.books.isEmpty)
        }
    }

    @Test("upsertBook 會沿用既有名稱並更新內容")
    func upsertBookReusesExistingName() throws {
        try withIsolatedDefaults {
            let store = LocalBankStore()
            let initial = makeItem(id: "item-6", text: "原始題")
            store.addOrReplaceBook(name: "Grammar", items: [initial])

            let updated = makeItem(id: "item-7", text: "更新題")
            let result = store.upsertBook(preferredName: "Grammar", existingName: "Grammar", items: [updated])

            #expect(result == "Grammar")
            #expect(store.items(in: "Grammar") == [updated])
            #expect(store.books.count == 1)
        }
    }

    @Test("upsertBook 會在名稱衝突時產生編號")
    func upsertBookGeneratesUniqueName() throws {
        try withIsolatedDefaults {
            let store = LocalBankStore()
            store.addOrReplaceBook(name: "Vocabulary", items: [makeItem(id: "item-8")])

            let newItem = makeItem(id: "item-9", text: "新題")
            let result = store.upsertBook(preferredName: "Vocabulary", items: [newItem])

            #expect(result == "Vocabulary (2)")
            #expect(store.items(in: "Vocabulary (2)") == [newItem])
            #expect(store.books.count == 2)
        }
    }

    @Test("重新初始化會載入保存的題庫")
    func persistenceRoundtripRestoresBooks() throws {
        try withIsolatedDefaults {
            let store = LocalBankStore()
            let item = makeItem(id: "item-5", text: "保存題目")
            store.addOrReplaceBook(name: "Book Persist", items: [item])

            let reloaded = LocalBankStore()

            #expect(reloaded.items(in: "Book Persist") == [item])
            #expect(reloaded.books.first?.name == "Book Persist")
        }
    }
}
