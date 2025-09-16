import Foundation
import SwiftUI

// A tiny, generic in-memory order helper that persists an array of keys.
// This is intentionally simple. Our decks/books views already have specific
// order stores; this provides a shared abstraction for future consolidation.

final class OrderStore<Key: Hashable & Codable>: ObservableObject {
    private let key: String
    @Published private(set) var order: [Key] = [] { didSet { persist() } }

    init(storageKey: String) {
        self.key = storageKey
        load()
    }

    func currentOrder(root: [Key]) -> [Key] {
        let rootSet = Set(root)
        let existing = order.filter { rootSet.contains($0) }
        let existingSet = Set(existing)
        let incoming = root.filter { !existingSet.contains($0) }
        return existing + incoming
    }

    func move(id: Key, to newIndex: Int, root: [Key]) {
        var r = currentOrder(root: root)
        guard let from = r.firstIndex(of: id) else { return }
        var to = max(0, min(newIndex, r.count))
        let item = r.remove(at: from)
        if from < to { to -= 1 }
        r.insert(item, at: to)
        // keep foreign ids
        let rootSet = Set(root)
        let others = order.filter { !rootSet.contains($0) }
        order = r + others
    }

    func remove(_ id: Key) { order.removeAll { $0 == id } }

    // MARK: persistence
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let arr = try? JSONDecoder().decode([Key].self, from: data) { order = arr }
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(order) { UserDefaults.standard.set(data, forKey: key) }
    }
}

