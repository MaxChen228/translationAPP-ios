import Foundation
import SwiftUI

struct PersistedFlashcardDeck: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var cards: [Flashcard]
}

@MainActor
final class FlashcardDecksStore: ObservableObject {
    private let defaultsKey = "saved.flashcard.decks"
    private let persistenceManager: PersistenceManager

    @Published private(set) var decks: [PersistedFlashcardDeck] = [] {
        didSet { persist() }
    }

    init(persistenceManager: PersistenceManager = UserDefaultsPersistenceManager()) {
        self.persistenceManager = persistenceManager
        load()
    }

    func add(name: String, cards: [Flashcard]) -> PersistedFlashcardDeck {
        let deck = PersistedFlashcardDeck(id: UUID(), name: name, cards: cards)
        decks.append(deck)
        return deck
    }

    func remove(_ id: UUID) {
        decks.removeAll { $0.id == id }
    }

    func updateCard(in deckID: UUID, card: Flashcard) {
        guard let i = decks.firstIndex(where: { $0.id == deckID }) else { return }
        if let ci = decks[i].cards.firstIndex(where: { $0.id == card.id }) {
            decks[i].cards[ci] = card
        }
    }

    func addCard(to deckID: UUID, card: Flashcard, at index: Int? = nil) {
        addCards(to: deckID, cards: [card], at: index)
    }

    func addCards(to deckID: UUID, cards newCards: [Flashcard], at index: Int? = nil) {
        guard !newCards.isEmpty else { return }
        guard let deckIndex = decks.firstIndex(where: { $0.id == deckID }) else { return }

        if let idx = index, idx >= 0 && idx <= decks[deckIndex].cards.count {
            decks[deckIndex].cards.insert(contentsOf: newCards, at: idx)
        } else {
            decks[deckIndex].cards.append(contentsOf: newCards)
        }
    }

    func deleteCard(from deckID: UUID, cardID: UUID) {
        guard let i = decks.firstIndex(where: { $0.id == deckID }) else { return }
        decks[i].cards.removeAll { $0.id == cardID }
    }

    func replaceCards(in deckID: UUID, with cards: [Flashcard]) {
        guard let idx = decks.firstIndex(where: { $0.id == deckID }) else { return }
        decks[idx].cards = cards
    }

    @discardableResult
    func removeCards(_ ids: Set<UUID>, from deckID: UUID) -> [Flashcard] {
        guard !ids.isEmpty, let deckIndex = decks.firstIndex(where: { $0.id == deckID }) else { return [] }
        let removed = decks[deckIndex].cards.filter { ids.contains($0.id) }
        decks[deckIndex].cards.removeAll { ids.contains($0.id) }
        return removed
    }

    @discardableResult
    func moveCards(_ ids: [UUID], from sourceID: UUID, to targetID: UUID) -> [Flashcard] {
        guard !ids.isEmpty, sourceID != targetID,
              let sourceIndex = decks.firstIndex(where: { $0.id == sourceID }),
              let targetIndex = decks.firstIndex(where: { $0.id == targetID }) else { return [] }

        let idSet = Set(ids)
        let orderedCards = decks[sourceIndex].cards.filter { idSet.contains($0.id) }
        guard !orderedCards.isEmpty else { return [] }

        decks[sourceIndex].cards.removeAll { idSet.contains($0.id) }
        decks[targetIndex].cards.append(contentsOf: orderedCards)
        return orderedCards
    }

    func rename(_ id: UUID, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let idx = decks.firstIndex(where: { $0.id == id }) {
            decks[idx].name = trimmed
        }
    }

    private func load() {
        if let loadedDecks = persistenceManager.load([PersistedFlashcardDeck].self, forKey: defaultsKey) {
            decks = loadedDecks
            AppLog.flashcardsDebug("Successfully loaded \(decks.count) flashcard decks from UserDefaults")
        } else {
            AppLog.flashcardsDebug("No existing flashcard decks data found in UserDefaults")
            decks = []
        }
    }

    private func persist() {
        do {
            try persistenceManager.save(decks, forKey: defaultsKey)
            AppLog.flashcardsDebug("Successfully persisted \(decks.count) flashcard decks to UserDefaults")
        } catch {
            AppLog.flashcardsError("Failed to persist flashcard decks to UserDefaults: \(error.localizedDescription)")
        }
    }

    // MARK: - Root-level ordering for decks
    func index(of id: UUID) -> Int? { decks.firstIndex(where: { $0.id == id }) }

    func moveDeck(id: UUID, to newIndex: Int) {
        guard let from = index(of: id) else { return }
        var to = newIndex
        let item = decks.remove(at: from)
        if from < to { to -= 1 }
        to = max(0, min(to, decks.count))
        decks.insert(item, at: to)
    }
}
