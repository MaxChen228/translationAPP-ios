import Foundation
import SwiftUI

struct LocalBankBook: Codable, Identifiable, Equatable {
    var id: String { name }
    var name: String
    var items: [BankItem]
}

@MainActor
final class LocalBankStore: ObservableObject {
    private let key = "local.bank.books"
    @Published private(set) var books: [LocalBankBook] = [] { didSet { persist() } }

    init() { load() }

    func addOrReplaceBook(name: String, items: [BankItem]) {
        if let i = books.firstIndex(where: { $0.name == name }) {
            books[i].items = items
        } else {
            books.append(LocalBankBook(name: name, items: items))
        }
    }

    @discardableResult
    func upsertBook(preferredName: String, existingName: String? = nil, items: [BankItem]) -> String {
        if let existingName, let index = books.firstIndex(where: { $0.name == existingName }) {
            books[index].items = items
            return existingName
        }

        let uniqueName = makeUniqueName(for: preferredName)
        if let index = books.firstIndex(where: { $0.name == uniqueName }) {
            books[index].items = items
        } else {
            books.append(LocalBankBook(name: uniqueName, items: items))
        }
        return uniqueName
    }

    func remove(_ name: String) { books.removeAll { $0.name == name } }

    func rename(_ from: String, to newName: String) {
        guard let i = books.firstIndex(where: { $0.name == from }) else { return }
        books[i].name = newName
    }

    func items(in name: String) -> [BankItem] {
        books.first(where: { $0.name == name })?.items ?? []
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let obj = try? JSONDecoder().decode([LocalBankBook].self, from: data) { books = obj }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(books) { UserDefaults.standard.set(data, forKey: key) }
    }

    private func makeUniqueName(for proposed: String) -> String {
        let trimmed = proposed.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return makeFallbackName() }

        var candidate = trimmed
        var suffix = 2
        while books.contains(where: { $0.name == candidate }) {
            candidate = "\(trimmed) (\(suffix))"
            suffix += 1
        }
        return candidate
    }

    private func makeFallbackName() -> String {
        var base = String(localized: "deck.untitled")
        if books.first(where: { $0.name == base }) == nil { return base }
        var suffix = 2
        while books.contains(where: { $0.name == "\(base) (\(suffix))" }) { suffix += 1 }
        return "\(base) (\(suffix))"
    }
}
