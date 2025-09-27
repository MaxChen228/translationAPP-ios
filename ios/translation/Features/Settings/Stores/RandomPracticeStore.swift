import Foundation
import SwiftUI

@MainActor
final class RandomPracticeStore: ObservableObject {
    private enum StorageKey {
        static let excludeCompleted = "random.excludeCompleted"
        static let selectedTags = "random.selectedTags"
        static let selectedCategories = "random.selectedCategories"
        static let filterMode = "random.filterMode"
        static let selectedDifficulties = "random.selectedDifficulties"
        static let selectedBooks = "random.selectedBooks"
    }

    @Published var excludeCompleted: Bool {
        didSet { persistExcludeCompleted() }
    }

    @Published var filterState: TagFilterState {
        didSet { persistFilterState() }
    }

    @Published var selectedDifficulties: Set<Int> {
        didSet { persistSelectedDifficulties() }
    }

    @Published var selectedBooks: Set<String> {
        didSet { persistSelectedBooks() }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.excludeCompleted = defaults.object(forKey: StorageKey.excludeCompleted) as? Bool ?? true
        self.filterState = RandomPracticeStore.loadFilterState(defaults: defaults)
        self.selectedDifficulties = RandomPracticeStore.loadSelectedDifficulties(defaults: defaults)
        self.selectedBooks = RandomPracticeStore.loadSelectedBooks(defaults: defaults)
    }

    func normalizedBookScope(with availableBooks: Set<String>) -> Set<String> {
        let scope = selectedBooks.intersection(availableBooks)
        if scope != selectedBooks {
            Task { @MainActor [weak self] in
                self?.selectedBooks = scope
            }
        }
        return scope
    }

    func setSelectedBooks(_ newValue: Set<String>) {
        selectedBooks = newValue
    }

    private func persistExcludeCompleted() {
        defaults.set(excludeCompleted, forKey: StorageKey.excludeCompleted)
    }

    private func persistFilterState() {
        let selectedTags = Array(filterState.selectedTags)
        defaults.set(selectedTags, forKey: StorageKey.selectedTags)

        let selectedCategories = Array(filterState.selectedCategories.map { $0.rawValue })
        defaults.set(selectedCategories, forKey: StorageKey.selectedCategories)

        defaults.set(filterState.filterMode.rawValue, forKey: StorageKey.filterMode)
    }

    private func persistSelectedDifficulties() {
        let values = Array(selectedDifficulties)
        defaults.set(values, forKey: StorageKey.selectedDifficulties)
    }

    private func persistSelectedBooks() {
        if selectedBooks.isEmpty {
            defaults.removeObject(forKey: StorageKey.selectedBooks)
        } else {
            defaults.set(Array(selectedBooks), forKey: StorageKey.selectedBooks)
        }
    }

    private static func loadFilterState(defaults: UserDefaults) -> TagFilterState {
        var state = TagFilterState()

        if let storedTags = defaults.array(forKey: StorageKey.selectedTags) as? [String] {
            state.selectedTags = Set(storedTags)
        }

        if let storedCategories = defaults.array(forKey: StorageKey.selectedCategories) as? [String] {
            let categories = storedCategories.compactMap { TagCategory(rawValue: $0) }
            state.selectedCategories = Set(categories)
        }

        if let storedMode = defaults.string(forKey: StorageKey.filterMode),
           let mode = TagFilterMode(rawValue: storedMode) {
            state.filterMode = mode
        }

        // Ensure category selections stay in sync with tag selections.
        syncCategories(&state)

        return state
    }

    private static func loadSelectedDifficulties(defaults: UserDefaults) -> Set<Int> {
        if let stored = defaults.array(forKey: StorageKey.selectedDifficulties) as? [Int] {
            return Set(stored)
        }
        return []
    }

    private static func loadSelectedBooks(defaults: UserDefaults) -> Set<String> {
        if let stored = defaults.array(forKey: StorageKey.selectedBooks) as? [String] {
            return Set(stored)
        }
        return []
    }

    private static func syncCategories(_ state: inout TagFilterState) {
        for category in TagCategory.allCases {
            let tags = Set(TagRegistry.tags(for: category))
            if tags.isSubset(of: state.selectedTags) {
                state.selectedCategories.insert(category)
            } else {
                state.selectedCategories.remove(category)
            }
        }
    }
}
