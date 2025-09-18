import Foundation
import SwiftUI

struct FlashcardProgress: Codable, Equatable {
    var level: Int // 精熟度，預設 0，可 +/- 調整
}

@MainActor
final class FlashcardProgressStore: ObservableObject {
    private let key = "flashcard.progress.map"
    // key format: "<deckID>:<cardID>" → level
    @Published private var map: [String: FlashcardProgress] = [:] { didSet { persist() } }

    init() { load() }

    private func k(_ deckID: UUID, _ cardID: UUID) -> String { "\(deckID.uuidString):\(cardID.uuidString)" }

    func level(deckID: UUID, cardID: UUID) -> Int {
        map[k(deckID, cardID)]?.level ?? 0
    }

    @discardableResult
    func adjust(deckID: UUID, cardID: UUID, delta: Int) -> Int {
        let key = k(deckID, cardID)
        var current = map[key]?.level ?? 0
        current &+= delta
        map[key] = FlashcardProgress(level: current)
        return current
    }

    func set(deckID: UUID, cardID: UUID, level: Int) {
        map[k(deckID, cardID)] = FlashcardProgress(level: level)
    }

    // MARK: - Persistence
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let obj = try? JSONDecoder().decode([String: FlashcardProgress].self, from: data) {
            map = obj
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(map) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}

