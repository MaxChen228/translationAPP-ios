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

    private func makeCorrectionPayload(savedAt: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> ErrorSavePayload {
        let error = ErrorItem(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            span: "go",
            type: .lexical,
            explainZh: "請改為過去式",
            suggestion: "went",
            hints: ErrorHints(before: "i ", after: " home", occurrence: 1)
        )
        return ErrorSavePayload(
            error: error,
            inputEn: "I go home.",
            correctedEn: "I went home.",
            inputZh: "我回家。",
            savedAt: savedAt
        )
    }

    private func makeResearchPayload(savedAt: Date = Date(timeIntervalSince1970: 1_700_000_100)) -> ResearchSavePayload {
        ResearchSavePayload(
            term: "lexicon",
            explanation: "解釋",
            context: "sample context",
            type: .lexical,
            savedAt: savedAt
        )
    }

    @Test("初始化時無現存資料應為空")
    func initializationWithEmptyDefaults() throws {
        try withIsolatedDefaults {
            let store = SavedErrorsStore()
            #expect(store.items.isEmpty)
        }
    }

    @Test("新增 correction 紀錄會持久化 JSON")
    func addCorrectionPersistsRecord() throws {
        try withIsolatedDefaults {
            let store = SavedErrorsStore()
            store.clearAll()

            let payload = makeCorrectionPayload()
            store.add(payload: payload)

            #expect(store.items.count == 1)
            guard let record = store.items.first else {
                Issue.record("no record created")
                return
            }

            #expect(record.source == .correction)
            #expect(record.stash == .left)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decodedPayload = try decoder.decode(ErrorSavePayload.self, from: Data(record.json.utf8))
            #expect(decodedPayload == payload)

            let persistedData = UserDefaults.standard.data(forKey: defaultsKey)
            #expect(persistedData != nil)
            if let data = persistedData {
                let persistedRecords = try JSONDecoder().decode([SavedErrorRecord].self, from: data)
                #expect(persistedRecords.count == 1)
                #expect(persistedRecords.first?.source == .correction)
            }
        }
    }

    @Test("新增 research 紀錄會標記來源與 stash")
    func addResearchPersistsRecord() throws {
        try withIsolatedDefaults {
            let store = SavedErrorsStore()
            store.clearAll()

            let payload = makeResearchPayload()
            store.add(research: payload)

            guard let record = store.items.first else {
                Issue.record("no record created")
                return
            }

            #expect(record.source == .research)
            #expect(record.stash == .left)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let decoded = try decoder.decode(ResearchSavePayload.self, from: Data(record.json.utf8))
            #expect(decoded == payload)
        }
    }

    @Test("移動紀錄會更新 stash 與計數")
    func moveRecordUpdatesStash() throws {
        try withIsolatedDefaults {
            let store = SavedErrorsStore()
            store.clearAll()
            store.add(payload: makeCorrectionPayload())

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

            store.add(payload: makeCorrectionPayload())
            store.add(research: makeResearchPayload())

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

            store.add(payload: makeCorrectionPayload())
            store.add(research: makeResearchPayload())

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

            store.add(payload: makeCorrectionPayload())
            store.add(research: makeResearchPayload())

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

            store.add(payload: makeCorrectionPayload())
            let snapshot = store.items

            store.move(UUID(), to: .right)

            #expect(store.items == snapshot)
        }
    }

    @Test("讀到毀損資料時應重置為空")
    func loadWithCorruptDataResets() throws {
        try withIsolatedDefaults {
            UserDefaults.standard.set(Data("not-json".utf8), forKey: defaultsKey)

            let store = SavedErrorsStore()
            #expect(store.items.isEmpty)
        }
    }
}

