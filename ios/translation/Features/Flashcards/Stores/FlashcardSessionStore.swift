import Foundation

@MainActor
final class FlashcardSessionStore: ObservableObject {
    @Published private(set) var cards: [Flashcard]
    @Published private(set) var index: Int
    @Published var showBack: Bool

    init(cards: [Flashcard] = FlashcardSessionStore.defaultCards, startIndex: Int = 0, showBack: Bool = false) {
        self.cards = cards
        let clamped = cards.isEmpty ? 0 : max(0, min(startIndex, cards.count - 1))
        self.index = clamped
        self.showBack = showBack
    }

    var isEmpty: Bool { cards.isEmpty }
    var count: Int { cards.count }
    var current: Flashcard? { cards.isEmpty ? nil : cards[index] }

    func setIndex(_ newIndex: Int) {
        guard !cards.isEmpty else {
            index = 0
            return
        }
        index = max(0, min(newIndex, cards.count - 1))
    }

    func next(loop: Bool = true) {
        guard !cards.isEmpty else { return }
        let nextIndex = index + 1
        if nextIndex >= cards.count {
            index = loop ? 0 : cards.count - 1
        } else {
            index = nextIndex
        }
        showBack = false
    }

    func previous(loop: Bool = true) {
        guard !cards.isEmpty else { return }
        let prevIndex = index - 1
        if prevIndex < 0 {
            index = loop ? cards.count - 1 : 0
        } else {
            index = prevIndex
        }
        showBack = false
    }

    func flip() {
        guard !cards.isEmpty else { return }
        showBack.toggle()
    }

    func updateCards(_ newCards: [Flashcard], prefer preferredID: UUID? = nil, defaultIndex: Int = 0) {
        cards = newCards
        if let preferredID, let idx = newCards.firstIndex(where: { $0.id == preferredID }) {
            index = idx
        } else if newCards.isEmpty {
            index = 0
        } else {
            index = max(0, min(defaultIndex, newCards.count - 1))
        }
        showBack = false
    }

    func shuffle(prefer preferredID: UUID? = nil) {
        guard !cards.isEmpty else { return }
        let currentID = cards.indices.contains(index) ? cards[index].id : nil
        var shuffled = cards.shuffled()
        if preferredID == nil, let currentID, cards.count > 1 {
            var attempts = 0
            while shuffled.first?.id == currentID && attempts < 4 {
                shuffled = cards.shuffled()
                attempts += 1
            }
        }
        updateCards(shuffled, prefer: preferredID, defaultIndex: 0)
    }

    func replaceCard(_ card: Flashcard) {
        guard let idx = cards.firstIndex(where: { $0.id == card.id }) else { return }
        cards[idx] = card
    }

    func removeCard(id: UUID) {
        guard let idx = cards.firstIndex(where: { $0.id == id }) else { return }
        cards.remove(at: idx)
        if cards.isEmpty {
            index = 0
        } else if index >= cards.count {
            index = cards.count - 1
        }
        showBack = false
    }

    func resetShowBack() {
        showBack = false
    }

    func index(of cardID: UUID) -> Int? {
        cards.firstIndex(where: { $0.id == cardID })
    }
}

extension FlashcardSessionStore {
    nonisolated static var defaultCards: [Flashcard] {
        [
            Flashcard(
                front: String(localized: "flashcards.sample1.front"),
                back: String(localized: "flashcards.sample1.back"),
                frontNote: nil,
                backNote: localizedOptional("flashcards.sample1.backNote")
            ),
            Flashcard(
                front: String(localized: "flashcards.sample2.front"),
                back: String(localized: "flashcards.sample2.back"),
                frontNote: nil,
                backNote: localizedOptional("flashcards.sample2.backNote")
            ),
            Flashcard(
                front: String(localized: "flashcards.sample3.front"),
                back: String(localized: "flashcards.sample3.back"),
                frontNote: nil,
                backNote: localizedOptional("flashcards.sample3.backNote")
            )
        ]
    }

    nonisolated private static func localizedOptional(_ key: String) -> String? {
        let value = Bundle.main.localizedString(forKey: key, value: "", table: nil)
        return value.isEmpty ? nil : value
    }
}
