import Foundation
import SwiftUI

@MainActor
final class DeckRootOrderStore: ObservableObject {
    private let key = "deck.root.order"
    @Published private(set) var order: [String] = [] { didSet { persist() } }

    init() { load() }

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
        guard let data = UserDefaults.standard.data(forKey: key) else {
            AppLog.flashcardsDebug("No existing deck root order data found in UserDefaults")
            return
        }
        do {
            order = try JSONDecoder().decode([String].self, from: data)
            AppLog.flashcardsDebug("Successfully loaded \(order.count) deck order items from UserDefaults")
        } catch {
            AppLog.flashcardsError("Failed to decode deck root order from UserDefaults: \(error.localizedDescription)")
            order = []
        }
    }

    private func persist() {
        do {
            let data = try JSONEncoder().encode(order)
            UserDefaults.standard.set(data, forKey: key)
            AppLog.flashcardsDebug("Successfully persisted \(order.count) deck order items to UserDefaults")
        } catch {
            AppLog.flashcardsError("Failed to persist deck root order to UserDefaults: \(error.localizedDescription)")
        }
    }
}

