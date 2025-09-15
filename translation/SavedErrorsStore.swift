import Foundation
import SwiftUI

struct ErrorSavePayload: Codable, Equatable {
    let error: ErrorItem
    let inputEn: String
    let correctedEn: String
    let inputZh: String
    let savedAt: Date
}

struct SavedErrorRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let json: String
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
            let record = SavedErrorRecord(id: UUID(), createdAt: Date(), json: json)
            items.append(record)
        }
    }

    func clearAll() { items = [] }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
    }

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
