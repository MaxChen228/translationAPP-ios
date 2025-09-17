import Foundation
import SwiftUI

struct LocalProgressRecord: Codable, Equatable {
    var completed: Bool = false
    var attempts: Int = 0
    var lastScore: Int? = nil
    var updatedAt: Date = Date()
}

@MainActor
final class LocalBankProgressStore: ObservableObject {
    private let key = "local.bank.progress"
    // Structure: [bookName: [itemId: LocalProgressRecord]]
    @Published private var map: [String: [String: LocalProgressRecord]] = [:] { didSet { persist() } }

    init() { load() }

    func markCompleted(book name: String, itemId: String, score: Int?) {
        var book = map[name] ?? [:]
        var rec = book[itemId] ?? LocalProgressRecord()
        rec.completed = true
        rec.attempts &+= 1
        rec.lastScore = score
        rec.updatedAt = Date()
        book[itemId] = rec
        map[name] = book
    }

    func isCompleted(book name: String, itemId: String) -> Bool {
        map[name]?[itemId]?.completed == true
    }

    func attempts(book name: String, itemId: String) -> Int { map[name]?[itemId]?.attempts ?? 0 }

    func stats(book name: String, totalItems: Int) -> (done: Int, total: Int) {
        let done = (map[name] ?? [:]).reduce(into: 0) { acc, kv in if kv.value.completed { acc += 1 } }
        return (min(done, totalItems), totalItems)
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let obj = try? JSONDecoder().decode([String: [String: LocalProgressRecord]].self, from: data) { map = obj }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(map) { UserDefaults.standard.set(data, forKey: key) }
    }

    // MARK: - Maintenance
    func removeBook(_ name: String) {
        map[name] = nil
    }

    func renameBook(from old: String, to new: String) {
        guard old != new else { return }
        let src = map[old] ?? [:]
        if map[new] == nil { map[new] = [:] }
        for (k, v) in src { map[new]?[k] = v }
        map[old] = nil
    }
}
