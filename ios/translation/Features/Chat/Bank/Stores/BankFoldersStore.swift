import Foundation
import SwiftUI

struct BankFolder: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var bookNames: [String]
    var courseId: String? = nil
    var courseBookNameMap: [String: String]? = nil
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
    func ensureCourseFolder(courseId: String, title: String) -> BankFolder {
        if let index = folders.firstIndex(where: { $0.courseId == courseId }) {
            if folders[index].name != title { folders[index].name = title }
            return folders[index]
        }
        let folder = BankFolder(id: UUID(), name: title, bookNames: [], courseId: courseId, courseBookNameMap: [:])
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

    func deleteFolder(
        _ id: UUID,
        cascadeWith localBank: LocalBankStore,
        progress: LocalBankProgressStore,
        order: BankBooksOrderStore
    ) {
        let names = removeFolder(id)
        BankCascadeDeletionService.deleteBooks(
            names,
            localBank: localBank,
            folders: self,
            progress: progress,
            order: order
        )
    }

    func rename(_ id: UUID, to newName: String) {
        guard let i = folders.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { folders[i].name = trimmed }
    }

    func renameCourseFolder(courseId: String, to newName: String) {
        guard let idx = folders.firstIndex(where: { $0.courseId == courseId }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { folders[idx].name = trimmed }
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
        if var map = folders[i].courseBookNameMap {
            map = map.filter { $0.value != bookName }
            folders[i].courseBookNameMap = map.isEmpty ? nil : map
        }
    }

    func remove(bookName: String) {
        for i in folders.indices {
            folders[i].bookNames.removeAll { $0 == bookName }
            if var map = folders[i].courseBookNameMap {
                map = map.filter { $0.value != bookName }
                folders[i].courseBookNameMap = map.isEmpty ? nil : map
            }
        }
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
            if var map = folders[i].courseBookNameMap {
                for key in map.keys where map[key] == old { map[key] = new }
                folders[i].courseBookNameMap = map
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

    func existingCourseBookName(courseId: String, courseBookId: String) -> String? {
        guard let folder = folders.first(where: { $0.courseId == courseId }) else { return nil }
        return folder.courseBookNameMap?[courseBookId]
    }

    func recordCourseBook(courseId: String, courseBookId: String, bookName: String) {
        guard let idx = folders.firstIndex(where: { $0.courseId == courseId }) else { return }
        var map = folders[idx].courseBookNameMap ?? [:]
        if let previous = map[courseBookId], previous != bookName {
            folders[idx].bookNames.removeAll { $0 == previous }
        }
        map[courseBookId] = bookName
        folders[idx].courseBookNameMap = map
        if !folders[idx].bookNames.contains(bookName) {
            folders[idx].bookNames.append(bookName)
        }
    }

    func removeCourseBookMapping(courseId: String, courseBookId: String) {
        guard let idx = folders.firstIndex(where: { $0.courseId == courseId }) else { return }
        guard var map = folders[idx].courseBookNameMap else { return }
        if let name = map.removeValue(forKey: courseBookId) {
            folders[idx].bookNames.removeAll { $0 == name }
        }
        folders[idx].courseBookNameMap = map.isEmpty ? nil : map
    }
}
