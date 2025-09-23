import Foundation
import SwiftUI

/// 可自訂的快速入口項目類型。
enum QuickActionType: String, Codable, CaseIterable {
    case chat
    case flashcards
    case bank
    case calendar
    case settings

    var titleKey: LocalizedStringKey {
        switch self {
        case .chat: return "chat.title"
        case .flashcards: return "quick.flashcards.title"
        case .bank: return "quick.bank.title"
        case .calendar: return "quick.calendar.title"
        case .settings: return "quick.settings.title"
        }
    }

    var subtitleKey: LocalizedStringKey? {
        switch self {
        case .chat: return "chat.subtitle"
        case .flashcards: return "quick.flashcards.subtitle"
        case .bank: return "quick.bank.subtitle"
        case .calendar: return nil
        case .settings: return "quick.settings.subtitle"
        }
    }

    var iconName: String {
        switch self {
        case .chat: return "bubble.left.and.bubble.right.fill"
        case .flashcards: return "rectangle.on.rectangle.angled"
        case .bank: return "books.vertical"
        case .calendar: return "calendar"
        case .settings: return "gearshape"
        }
    }

    var accentColor: Color {
        switch self {
        case .chat: return DS.Brand.scheme.classicBlue
        case .flashcards: return DS.Brand.scheme.provence
        case .bank: return DS.Brand.scheme.stucco
        case .calendar: return DS.Brand.scheme.provence
        case .settings: return DS.Palette.primary
        }
    }
}

struct QuickActionItem: Identifiable, Codable, Hashable {
    let id: UUID
    var type: QuickActionType

    init(id: UUID = UUID(), type: QuickActionType) {
        self.id = id
        self.type = type
    }
}

/// 管理首頁快速入口的資料來源，支援新增、移除與持久化。
final class QuickActionsStore: ObservableObject {
    @Published private(set) var items: [QuickActionItem] {
        didSet {
            persist()
        }
    }

    private let storageKey = "quickActions.v1"
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()

        if let stored = Self.load(from: userDefaults, decoder: decoder, key: storageKey) {
            items = stored
        } else {
            let defaults = Self.defaultItems
            items = defaults
            persist()
        }
    }

    func append(_ type: QuickActionType) {
        items.append(QuickActionItem(type: type))
    }

    func remove(id: UUID) {
        items.removeAll { $0.id == id }
    }

    func remove(ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        items.removeAll { ids.contains($0.id) }
    }

    func move(from source: Int, to destination: Int) {
        guard source != destination,
              items.indices.contains(source) else { return }
        let item = items.remove(at: source)
        let idx = min(max(destination, 0), items.count)
        items.insert(item, at: idx)
    }

    func move(ids: [UUID], before targetID: UUID?) {
        let idSet = Set(ids)
        guard !idSet.isEmpty else { return }

        let moving = items.filter { idSet.contains($0.id) }
        guard !moving.isEmpty else { return }

        items.removeAll { idSet.contains($0.id) }

        let insertIndex: Int
        if let targetID, let idx = items.firstIndex(where: { $0.id == targetID }) {
            insertIndex = idx
        } else {
            insertIndex = items.count
        }

        let clampedIndex = max(0, min(insertIndex, items.count))
        items.insert(contentsOf: moving, at: clampedIndex)
    }

    func index(of id: UUID) -> Int? {
        items.firstIndex { $0.id == id }
    }

    func resetToDefaults() {
        items = Self.defaultItems
    }

    // MARK: - Private

    private let userDefaults: UserDefaults

    private func persist() {
        guard let data = try? encoder.encode(items) else { return }
        userDefaults.set(data, forKey: storageKey)
    }

    private static func load(from defaults: UserDefaults, decoder: JSONDecoder, key: String) -> [QuickActionItem]? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode([QuickActionItem].self, from: data)
    }

    private static var defaultItems: [QuickActionItem] {
        [
            QuickActionItem(type: .chat),
            QuickActionItem(type: .flashcards),
            QuickActionItem(type: .bank),
            QuickActionItem(type: .calendar),
            QuickActionItem(type: .settings)
        ]
    }
}
