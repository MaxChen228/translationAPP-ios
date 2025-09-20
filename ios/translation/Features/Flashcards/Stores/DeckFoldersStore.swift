import Foundation
import SwiftUI

struct DeckFolder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var deckIDs: [UUID]
}

@MainActor
final class DeckFoldersStore: ObservableObject {
    private let key = "saved.flashcard.folders"

    @Published private(set) var folders: [DeckFolder] = [] {
        didSet { persist() }
    }

    init() { load() }

    // MARK: - CRUD
    @discardableResult
    func addFolder(name: String = String(localized: "folder.new")) -> DeckFolder {
        let fallback = String(localized: "folder.new")
        let folder = DeckFolder(id: UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : name, deckIDs: [])
        folders.append(folder)
        return folder
    }

    @discardableResult
    func removeFolder(_ id: UUID) -> [UUID] {
        guard let i = folders.firstIndex(where: { $0.id == id }) else { return [] }
        let ids = folders[i].deckIDs
        folders.remove(at: i)
        return ids
    }

    func rename(_ id: UUID, to newName: String) {
        guard let i = folders.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { folders[i].name = trimmed }
    }

    // MARK: - Membership
    func folderID(containing deckID: UUID) -> UUID? {
        for f in folders { if f.deckIDs.contains(deckID) { return f.id } }
        return nil
    }

    func add(deckID: UUID, to folderID: UUID) {
        guard let i = folders.firstIndex(where: { $0.id == folderID }) else { return }
        // 確保單一歸屬：先從其他資料夾移除
        remove(deckID: deckID)
        if !folders[i].deckIDs.contains(deckID) { folders[i].deckIDs.append(deckID) }
    }

    func remove(deckID: UUID, from folderID: UUID) {
        guard let i = folders.firstIndex(where: { $0.id == folderID }) else { return }
        folders[i].deckIDs.removeAll { $0 == deckID }
    }

    func remove(deckID: UUID) {
        for i in folders.indices { folders[i].deckIDs.removeAll { $0 == deckID } }
    }

    // 於資料夾內排序
    func moveInFolder(folderID: UUID, deckID: UUID, to newIndex: Int) {
        guard let i = folders.firstIndex(where: { $0.id == folderID }) else { return }
        guard let from = folders[i].deckIDs.firstIndex(of: deckID) else { return }
        var to = max(0, min(newIndex, folders[i].deckIDs.count - 1))
        let item = folders[i].deckIDs.remove(at: from)
        if from < to { to -= 1 }
        folders[i].deckIDs.insert(item, at: to)
    }

    // 根層：過濾未歸入資料夾的 deck IDs
    func isInAnyFolder(_ deckID: UUID) -> Bool {
        return folders.contains { $0.deckIDs.contains(deckID) }
    }

    // MARK: - Persistence
    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        if let obj = try? JSONDecoder().decode([DeckFolder].self, from: data) {
            folders = obj
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
