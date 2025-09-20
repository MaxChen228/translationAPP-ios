import Foundation
import SwiftUI

struct BankFolder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var bookNames: [String]
}

@MainActor
final class BankFoldersStore: ObservableObject {
    private let key = "bank.folders"

    @Published private(set) var folders: [BankFolder] = [] {
        didSet { persist() }
    }

    init() { load() }

    // MARK: - CRUD
    @discardableResult
    func addFolder(name: String = String(localized: "folder.new")) -> BankFolder {
        let fallback = String(localized: "folder.new")
        let folder = BankFolder(id: UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : name, bookNames: [])
        folders.append(folder)
        return folder
    }

    @discardableResult
    func removeFolder(_ id: UUID) -> [String] {
        guard let i = folders.firstIndex(where: { $0.id == id }) else { return [] }
        let names = folders[i].bookNames
        folders.remove(at: i)
        return names
    }

    func rename(_ id: UUID, to newName: String) {
        guard let i = folders.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { folders[i].name = trimmed }
    }

    // MARK: - Membership
    func folderID(containing bookName: String) -> UUID? {
        for f in folders { if f.bookNames.contains(bookName) { return f.id } }
        return nil
    }

    func add(bookName: String, to folderID: UUID) {
        guard let i = folders.firstIndex(where: { $0.id == folderID }) else { return }
        remove(bookName: bookName)
        if !folders[i].bookNames.contains(bookName) { folders[i].bookNames.append(bookName) }
    }

    func remove(bookName: String, from folderID: UUID) {
        guard let i = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[i].bookNames.removeAll { $0 == bookName }
    }

    func remove(bookName: String) {
        for i in folders.indices { folders[i].bookNames.removeAll { $0 == bookName } }
    }

    // Replace a book name across all folders to keep membership consistent after rename.
    func replaceBookName(old: String, with new: String) {
        for i in folders.indices {
            if let idx = folders[i].bookNames.firstIndex(of: old) {
                if !folders[i].bookNames.contains(new) {
                    folders[i].bookNames[idx] = new
                } else {
                    // Avoid duplicates: if new already exists, just remove the old one
                    folders[i].bookNames.remove(at: idx)
                }
            }
        }
    }

    func isInAnyFolder(_ bookName: String) -> Bool {
        return folders.contains { $0.bookNames.contains(bookName) }
    }

    // MARK: - Persistence
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let obj = try? JSONDecoder().decode([BankFolder].self, from: data) {
            folders = obj
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
