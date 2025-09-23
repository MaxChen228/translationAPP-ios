import Foundation
import SwiftUI

struct ErrorSavePayload: Codable, Equatable {
    let error: ErrorItem
    let inputEn: String
    let correctedEn: String
    let inputZh: String
    let savedAt: Date
}

struct ResearchSavePayload: Codable, Equatable {
    let term: String
    let explanation: String
    let context: String
    let type: ErrorType
    let savedAt: Date
}

enum SavedStash: String, Codable, CaseIterable, Identifiable {
    case left
    case right
    var id: String { rawValue }
}

enum SavedSource: String, Codable {
    case correction
    case research
}

struct SavedErrorRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    var json: String
    var stash: SavedStash = .left
    var source: SavedSource = .correction

    private enum CodingKeys: String, CodingKey {
        case id, createdAt, json, stash, source
    }

    init(id: UUID, createdAt: Date, json: String, stash: SavedStash, source: SavedSource) {
        self.id = id
        self.createdAt = createdAt
        self.json = json
        self.stash = stash
        self.source = source
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        json = try container.decode(String.self, forKey: .json)
        stash = try container.decodeIfPresent(SavedStash.self, forKey: .stash) ?? .left
        source = try container.decodeIfPresent(SavedSource.self, forKey: .source) ?? .correction
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(json, forKey: .json)
        try container.encode(stash, forKey: .stash)
        try container.encode(source, forKey: .source)
    }
}

@MainActor
final class SavedErrorsStore: ObservableObject {
    private let defaultsKey = "saved.error.records"

    @Published private(set) var items: [SavedErrorRecord] = [] {
        didSet { persist() }
    }

    init() { load() }

    func add(payload: ErrorSavePayload) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let data = try? encoder.encode(payload), let json = String(data: data, encoding: .utf8) {
            let record = SavedErrorRecord(id: UUID(), createdAt: Date(), json: json, stash: .left, source: .correction)
            items.append(record)
        }
    }

    func add(research payload: ResearchSavePayload) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let data = try? encoder.encode(payload), let json = String(data: data, encoding: .utf8) {
            let record = SavedErrorRecord(id: UUID(), createdAt: Date(), json: json, stash: .left, source: .research)
            items.append(record)
        }
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
}
