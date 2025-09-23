import Foundation
import SwiftUI

@MainActor
final class DeckRootOrderStore: ObservableObject {
    private let key = "deck.root.order"
    private let persistenceManager: PersistenceManager
    @Published private(set) var order: [String] = [] { didSet { persist() } }

    init(persistenceManager: PersistenceManager = UserDefaultsPersistenceManager()) {
        self.persistenceManager = persistenceManager
        load()
    }

    // Ensure every id in rootIDs appears in order, append missing to the end.
    func ensure(rootIDs: [String]) {
        var set = Set(order)
        var changed = false
        for id in rootIDs where !set.contains(id) {
            order.append(id)
            set.insert(id)
            changed = true
        }
        if changed { persist() }
    }

    func currentOrder(rootIDs: [String]) -> [String] {
        let rootSet = Set(rootIDs)
        let existing = order.filter { rootSet.contains($0) }
        let existingSet = Set(existing)
        let incoming = rootIDs.filter { !existingSet.contains($0) }
        return existing + incoming
    }

    func indexInRoot(_ id: String, rootIDs: [String]) -> Int? {
        let r = currentOrder(rootIDs: rootIDs)
        return r.firstIndex(of: id)
    }

    func move(id: String, to newIndex: Int, rootIDs: [String]) {
        var r = currentOrder(rootIDs: rootIDs)
        guard let from = r.firstIndex(of: id) else { return }
        var to = max(0, min(newIndex, r.count))
        let item = r.remove(at: from)
        if from < to { to -= 1 }
        r.insert(item, at: to)
        let rootSet = Set(rootIDs)
        let others = order.filter { !rootSet.contains($0) }
        order = r + others
    }

    func move(ids: [String], before targetID: String?, rootIDs: [String]) {
        let idSet = Set(ids)
        guard !idSet.isEmpty else { return }
        var r = currentOrder(rootIDs: rootIDs)
        let moving = r.filter { idSet.contains($0) }
        guard !moving.isEmpty else { return }
        r.removeAll { idSet.contains($0) }

        let insertIndex: Int
        if let targetID, let idx = r.firstIndex(of: targetID) {
            insertIndex = idx
        } else {
            insertIndex = r.count
        }

        let clamped = max(0, min(insertIndex, r.count))
        r.insert(contentsOf: moving, at: clamped)

        let rootSet = Set(rootIDs)
        let others = order.filter { !rootSet.contains($0) }
        order = r + others
    }

    func removeFromOrder(_ id: String) {
        order.removeAll { $0 == id }
    }

    func insertIntoOrder(_ id: String, at index: Int, rootIDs: [String]) {
        var r = currentOrder(rootIDs: rootIDs)
        let clamped = max(0, min(index, r.count))
        r.insert(id, at: clamped)
        let rootSet = Set(rootIDs)
        let others = order.filter { !rootSet.contains($0) }
        order = r + others
    }

    // MARK: - Persistence
    private func load() {
        if let loadedOrder = persistenceManager.load([String].self, forKey: key) {
            order = loadedOrder
            AppLog.flashcardsDebug("Successfully loaded \(order.count) deck order items from UserDefaults")
        } else {
            AppLog.flashcardsDebug("No existing deck root order data found in UserDefaults")
            order = []
        }
    }

    private func persist() {
        do {
            try persistenceManager.save(order, forKey: key)
            AppLog.flashcardsDebug("Successfully persisted \(order.count) deck order items to UserDefaults")
        } catch {
            AppLog.flashcardsError("Failed to persist deck root order to UserDefaults: \(error.localizedDescription)")
        }
    }
}
