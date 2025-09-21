import Foundation
import SwiftUI

enum TagCategory: String, CaseIterable, Identifiable {
    case grammar = "語法結構"
    case structure = "特定結構"
    case function = "語法功能"
    case topic = "語意主題"
    case tense = "時態語態"

    var id: String { rawValue }

    var iconSystemName: String {
        switch self {
        case .grammar: return "textformat.abc"
        case .structure: return "building.2"
        case .function: return "bubble.left.and.bubble.right"
        case .topic: return "person.2"
        case .tense: return "clock"
        }
    }

    var color: TagCategoryColor {
        switch self {
        case .grammar: return .blue
        case .structure: return .green
        case .function: return .orange
        case .topic: return .purple
        case .tense: return .red
        }
    }
}

enum TagCategoryColor {
    case blue, green, orange, purple, red

    var accentColor: Color {
        switch self {
        case .blue: return DS.Brand.scheme.classicBlue
        case .green: return DS.Brand.scheme.stucco
        case .orange: return DS.Brand.scheme.peachQuartz
        case .purple: return DS.Brand.scheme.provence
        case .red: return Color.red
        }
    }

    var lightColor: Color {
        accentColor.opacity(DS.Opacity.fill)
    }
}

struct TagRegistry {
    private static let grammarTags = [
        "subjunctive", "conditional", "cleft", "inversion", "emphasis", "comparative",
        "superlative", "passive", "modal", "infinitive", "gerund", "participle",
        "relative-clause", "noun-clause", "adverb-clause", "as-clause",
        "complex-sentence", "grammar"
    ]

    private static let structureTags = [
        "as-adjective-as", "as-soon-as", "as-long-as", "as-far-as", "the-more-the-more",
        "would-rather", "had-better", "used-to", "be-used-to", "too-to", "so-that",
        "such-that", "not-only-but-also", "either-or", "neither-nor"
    ]

    private static let functionTags = [
        "advice", "warning", "request", "permission", "prohibition", "suggestion",
        "offer", "invitation", "complaint", "apology", "opinion", "preference",
        "regret", "possibility", "necessity", "ability", "purpose", "result", "cause"
    ]

    private static let topicTags = [
        "family", "education", "career", "health", "money", "relationship", "travel",
        "food", "sports", "entertainment", "technology", "environment", "culture",
        "business", "academic", "personal", "social", "daily-life"
    ]

    private static let tenseTags = [
        "present-simple", "present-continuous", "present-perfect", "past-simple",
        "past-continuous", "past-perfect", "future-simple", "future-perfect"
    ]

    static func tags(for category: TagCategory) -> [String] {
        switch category {
        case .grammar: return grammarTags
        case .structure: return structureTags
        case .function: return functionTags
        case .topic: return topicTags
        case .tense: return tenseTags
        }
    }

    static func category(for tag: String) -> TagCategory? {
        for category in TagCategory.allCases {
            if tags(for: category).contains(tag) {
                return category
            }
        }
        return nil
    }

    static var allTags: [String] {
        TagCategory.allCases.flatMap { tags(for: $0) }
    }

    static func localizedName(for tag: String) -> String {
        let key = "tag.\(tag.replacingOccurrences(of: "-", with: "_"))"
        let localized = String(localized: String.LocalizationValue(key))
        return localized != key ? localized : tag
    }

    static func searchTags(query: String) -> [String] {
        let lowercaseQuery = query.lowercased()
        return allTags.filter { tag in
            tag.lowercased().contains(lowercaseQuery) ||
            localizedName(for: tag).lowercased().contains(lowercaseQuery)
        }
    }
}

struct TagFilterState {
    var selectedCategories: Set<TagCategory> = []
    var selectedTags: Set<String> = []
    var filterMode: TagFilterMode = .intersection
    var isExpanded: Set<TagCategory> = []
    var selectsAll: Bool = false

    var hasActiveFilters: Bool {
        !selectsAll && (!selectedCategories.isEmpty || !selectedTags.isEmpty)
    }

    mutating func clear() {
        selectsAll = false
        selectedCategories.removeAll()
        selectedTags.removeAll()
    }

    mutating func setSelectAll(_ newValue: Bool) {
        selectsAll = newValue
        if newValue {
            selectedCategories.removeAll()
            selectedTags.removeAll()
        }
    }

    mutating func toggleCategory(_ category: TagCategory) {
        selectsAll = false
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
            for tag in TagRegistry.tags(for: category) {
                selectedTags.remove(tag)
            }
        } else {
            selectedCategories.insert(category)
            for tag in TagRegistry.tags(for: category) {
                selectedTags.insert(tag)
            }
        }
    }

    mutating func toggleTag(_ tag: String) {
        selectsAll = false
        if selectedTags.contains(tag) {
            selectedTags.remove(tag)
            if let category = TagRegistry.category(for: tag) {
                let categoryTags = TagRegistry.tags(for: category)
                if categoryTags.allSatisfy({ !selectedTags.contains($0) }) {
                    selectedCategories.remove(category)
                }
            }
        } else {
            selectedTags.insert(tag)
            if let category = TagRegistry.category(for: tag) {
                let categoryTags = TagRegistry.tags(for: category)
                if categoryTags.allSatisfy({ selectedTags.contains($0) }) {
                    selectedCategories.insert(category)
                }
            }
        }
    }

    func matches(tags: [String]) -> Bool {
        if selectsAll { return true }
        guard hasActiveFilters else { return true }

        switch filterMode {
        case .intersection:
            return !selectedTags.isDisjoint(with: Set(tags))
        case .union:
            return selectedTags.isSubset(of: Set(tags))
        }
    }
}

enum TagFilterMode: String, CaseIterable {
    case intersection = "任一匹配"
    case union = "全部匹配"

    var systemImage: String {
        switch self {
        case .intersection: return "circle.grid.cross"
        case .union: return "circle.grid.cross.fill"
        }
    }
}
