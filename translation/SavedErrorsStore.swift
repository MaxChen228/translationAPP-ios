import Foundation
import SwiftUI

struct ErrorSavePayload: Codable, Equatable {
    let error: ErrorItem
    let inputEn: String
    let correctedEn: String
    let inputZh: String
    let savedAt: Date
}

enum SavedStash: String, Codable, CaseIterable, Identifiable {
    case left
    case right
    var id: String { rawValue }
}

struct SavedErrorRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let json: String
    // Which temporary stash this record belongs to. Defaults to .left for backward compatibility.
    var stash: SavedStash = .left
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
            let record = SavedErrorRecord(id: UUID(), createdAt: Date(), json: json, stash: .left)
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
