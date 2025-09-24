import Foundation
import SwiftUI

/// 精煉後的知識點資料，僅保留修正後需要複習的內容。
struct KnowledgeSavePayload: Codable, Equatable {
    let id: UUID
    let savedAt: Date
    let title: String
    let explanation: String
    let correctExample: String
    let note: String?
    let sourceHintID: UUID?
}

enum SavedStash: String, Codable, CaseIterable, Identifiable {
    case left
    case right
    var id: String { rawValue }
}

struct SavedErrorRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    var json: String
    var stash: SavedStash = .left

    private enum CodingKeys: String, CodingKey {
        case id, createdAt, json, stash
    }

    init(id: UUID, createdAt: Date, json: String, stash: SavedStash) {
        self.id = id
        self.createdAt = createdAt
        self.json = json
        self.stash = stash
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        json = try container.decode(String.self, forKey: .json)
        stash = try container.decodeIfPresent(SavedStash.self, forKey: .stash) ?? .left
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(json, forKey: .json)
        try container.encode(stash, forKey: .stash)
    }
}

@MainActor
final class SavedErrorsStore: ObservableObject {
    private let defaultsKey = "saved.error.records"

    @Published private(set) var items: [SavedErrorRecord] = [] {
        didSet {
            persist()
            rebuildHintIDs()
        }
    }

    private let encoder: JSONEncoder
    private var hintIDs: Set<UUID> = []

    init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        self.encoder = encoder
        load()
    }

    func addKnowledge(_ payload: KnowledgeSavePayload, stash: SavedStash = .left) {
        guard let data = try? encoder.encode(payload),
              let json = String(data: data, encoding: .utf8) else { return }
        let record = SavedErrorRecord(id: UUID(), createdAt: Date(), json: json, stash: stash)
        items.append(record)
    }

    func addKnowledge(
        title: String,
        explanation: String,
        correctExample: String,
        note: String? = nil,
        savedAt: Date = Date(),
        stash: SavedStash = .left,
        sourceHintID: UUID? = nil
    ) {
        let payload = KnowledgeSavePayload(
            id: UUID(),
            savedAt: savedAt,
            title: title,
            explanation: explanation,
            correctExample: correctExample,
            note: note?.isEmpty == true ? nil : note,
            sourceHintID: sourceHintID
        )
        addKnowledge(payload, stash: stash)
    }

    enum HintSaveResult { case added, duplicate }

    func addHint(
        _ hint: BankHint,
        categoryLabel: String,
        stash: SavedStash = .left,
        savedAt: Date = Date()
    ) -> HintSaveResult {
        if hintIDs.contains(hint.id) { return .duplicate }
        let payload = KnowledgeSavePayload(
            id: UUID(),
            savedAt: savedAt,
            title: hint.text,
            explanation: "",
            correctExample: "",
            note: categoryLabel,
            sourceHintID: hint.id
        )
        addKnowledge(payload, stash: stash)
        return .added
    }

    func containsHint(_ hint: BankHint) -> Bool {
        hintIDs.contains(hint.id)
    }

    func clearAll() { items = [] }

    func clear(_ stash: SavedStash) {
        items.removeAll { $0.stash == stash }
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

    func move(_ id: UUID, to stash: SavedStash) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].stash = stash
    }

    func update(_ id: UUID, json: String) {
        guard let idx = items.firstIndex(where: { $0.id == id }) else { return }
        items[idx].json = json
    }

    func items(in stash: SavedStash) -> [SavedErrorRecord] {
        items.filter { $0.stash == stash }
    }

    func count(in stash: SavedStash) -> Int { items(in: stash).count }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        do {
            items = try JSONDecoder().decode([SavedErrorRecord].self, from: data)
        } catch {
            items = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(items)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            // ignore persist errors
        }
    }

    private func rebuildHintIDs() {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        hintIDs = Set(items.compactMap { record in
            guard let data = record.json.data(using: .utf8),
                  let payload = try? decoder.decode(KnowledgeSavePayload.self, from: data) else { return nil }
            return payload.sourceHintID
        }.compactMap { $0 })
    }
}
