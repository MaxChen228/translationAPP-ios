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
}

