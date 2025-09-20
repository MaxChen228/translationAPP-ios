import Foundation
import SwiftUI

@MainActor
final class BankBooksOrderStore: ObservableObject {
    private let key = "bank.books.order"
    @Published private(set) var order: [String] = [] { didSet { persist() } }

    init() { load() }

    func ensure(names: [String]) {
        var set = Set(order)
        var changed = false
        for n in names where !set.contains(n) {
            order.append(n)
            set.insert(n)
            changed = true
        }
        if changed { persist() }
    }

    func currentRootOrder(root: [String]) -> [String] {
        let rootSet = Set(root)
        let existing = order.filter { rootSet.contains($0) }
        let existingSet = Set(existing)
        let incoming = root.filter { !existingSet.contains($0) }
        return existing + incoming
    }

    func indexInRoot(_ name: String, root: [String]) -> Int? {
        let r = currentRootOrder(root: root)
        return r.firstIndex(of: name)
    }

    func moveInRoot(id: String, to newIndex: Int, root: [String]) {
        var r = currentRootOrder(root: root)
        guard let from = r.firstIndex(of: id) else { return }
        var to = max(0, min(newIndex, r.count))
        let item = r.remove(at: from)
        if from < to { to -= 1 }
        r.insert(item, at: to)
        let rootSet = Set(root)
        let others = order.filter { !rootSet.contains($0) }
        order = r + others
    }

    // MARK: - Persistence
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let arr = try? JSONDecoder().decode([String].self, from: data) { order = arr }
    }
    private func persist() {
        if let data = try? JSONEncoder().encode(order) { UserDefaults.standard.set(data, forKey: key) }
    }
}

