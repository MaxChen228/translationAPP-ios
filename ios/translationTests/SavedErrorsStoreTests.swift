import Foundation
import Testing
@testable import translation

@MainActor
@Suite("SavedErrorsStore")
struct SavedErrorsStoreTests {
    private let defaultsKey = "saved.error.records"

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

    private func makeKnowledgePayload(savedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> KnowledgeSavePayload {
        KnowledgeSavePayload(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            savedAt: savedAt,
            title: "went",
            explanation: "過去式需使用 went。",
            correctExample: "I went to school yesterday.",
            note: "lexical",
            sourceHintID: nil
        )
    }

    @Test("初始化時無現存資料應為空")
    func initializationWithEmptyDefaults() throws {
        try withIsolatedDefaults {
            let store = SavedErrorsStore()
            #expect(store.items.isEmpty)
        }
    }

    @Test("新增知識點會持久化 JSON")
    func addKnowledgePersistsRecord() throws {
        try withIsolatedDefaults {
            let store = SavedErrorsStore()
            store.clearAll()

            let payload = makeKnowledgePayload()
            store.addKnowledge(payload)

            #expect(store.items.count == 1)
            guard let record = store.items.first else {
                Issue.record("no record created")
                return
            }

            #expect(record.stash == .left)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decodedPayload = try decoder.decode(KnowledgeSavePayload.self, from: Data(record.json.utf8))
            #expect(decodedPayload == payload)

            let persistedData = UserDefaults.standard.data(forKey: defaultsKey)
            #expect(persistedData != nil)
            if let data = persistedData {
                let persistedRecords = try JSONDecoder().decode([SavedErrorRecord].self, from: data)
                #expect(persistedRecords.count == 1)
            }
        }
    }

    @Test("便利方法可直接建立知識點")
    func convenienceAdderBuildsPayload() throws {
        try withIsolatedDefaults {
            let store = SavedErrorsStore()
            store.clearAll()

            store.addKnowledge(
                title: "make",
                explanation: "改用 make 某物。",
                correctExample: "I made dinner.",
                note: "lexical",
                savedAt: Date(timeIntervalSince1970: 1_700_000_123)
            )

            guard let record = store.items.first else {
                Issue.record("no record created")
                return
            }

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payload = try decoder.decode(KnowledgeSavePayload.self, from: Data(record.json.utf8))
            #expect(payload.title == "make")
            #expect(payload.correctExample == "I made dinner.")
            #expect(payload.note == "lexical")
        }
    }

    @Test("移動紀錄會更新 stash 與計數")
    func moveRecordUpdatesStash() throws {
        try withIsolatedDefaults {
            let store = SavedErrorsStore()
            store.clearAll()
            store.addKnowledge(makeKnowledgePayload())

            guard let id = store.items.first?.id else {
                Issue.record("missing record id")
                return
            }

            store.move(id, to: .right)

            #expect(store.items.first?.stash == .right)
            #expect(store.items(in: .left).isEmpty)
            #expect(store.items(in: .right).count == 1)
            #expect(store.count(in: .right) == 1)
        }
    }

    @Test("清除指定 stash 僅影響該區")
    func clearSpecificStash() throws {
        try withIsolatedDefaults {
            let store = SavedErrorsStore()
            store.clearAll()

            store.addKnowledge(makeKnowledgePayload())
            store.addKnowledge(title: "study", explanation: "記錄複習紀錄", correctExample: "I studied yesterday.")

            guard let firstID = store.items.first?.id else {
                Issue.record("missing first record id")
                return
            }

            store.move(firstID, to: .right)

            store.clear(.left)

            #expect(store.items.count == 1)
            #expect(store.items.first?.stash == .right)
        }
    }

    @Test("移除指定紀錄並同步持久化")
    func removeRecordPersistsChange() throws {
        try withIsolatedDefaults {
            let store = SavedErrorsStore()
            store.clearAll()

            store.addKnowledge(makeKnowledgePayload())
            store.addKnowledge(title: "study", explanation: "記錄複習紀錄", correctExample: "I studied yesterday.")

            guard let id = store.items.first?.id else {
                Issue.record("missing record id")
                return
            }

            store.remove(id)

            #expect(store.items.count == 1)
            let persistedData = UserDefaults.standard.data(forKey: defaultsKey)
            if let data = persistedData {
                let persistedRecords = try JSONDecoder().decode([SavedErrorRecord].self, from: data)
                #expect(persistedRecords.count == 1)
            }
        }
    }

    @Test("clearAll 會清空所有紀錄")
    func clearAllRemovesEverything() throws {
        try withIsolatedDefaults {
            let store = SavedErrorsStore()
            store.clearAll()

            store.addKnowledge(makeKnowledgePayload())
            store.addKnowledge(title: "study", explanation: "記錄複習紀錄", correctExample: "I studied yesterday.")

            store.clearAll()

            #expect(store.items.isEmpty)
            let persistedData = UserDefaults.standard.data(forKey: defaultsKey)
            if let data = persistedData {
                let persisted = try JSONDecoder().decode([SavedErrorRecord].self, from: data)
                #expect(persisted.isEmpty)
            }
        }
    }

    @Test("移動不存在的紀錄不應有副作用")
    func moveNonexistentRecordHasNoEffect() throws {
        try withIsolatedDefaults {
            let store = SavedErrorsStore()
            store.clearAll()

            store.addKnowledge(makeKnowledgePayload())
            let snapshot = store.items

            store.move(UUID(), to: .right)

            #expect(store.items == snapshot)
        }
    }

    @Test("addHint 會依提示 ID 避免重複")
    func addHintEnforcesUniqueness() throws {
        try withIsolatedDefaults {
            let store = SavedErrorsStore()
            store.clearAll()

            let hint = BankHint(category: .lexical, text: "用 attach to 表示附加")

            #expect(store.addHint(hint, prompt: "原句") == .added)
            #expect(store.containsHint(hint))
            #expect(store.items.count == 1)

            #expect(store.addHint(hint, prompt: "原句") == .duplicate)
            #expect(store.items.count == 1)
            if let record = store.items.first {
                let decoder = JSONDecoder()
                decoder.dateDecodingStrategy = .iso8601
                let payload = try decoder.decode(KnowledgeSavePayload.self, from: Data(record.json.utf8))
                #expect(payload.explanation == "原句")
                #expect(payload.note == nil)
            }
        }
    }
}
