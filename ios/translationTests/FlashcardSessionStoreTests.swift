import Foundation
import Testing
@testable import translation

@MainActor
@Suite("FlashcardSessionStore")
struct FlashcardSessionStoreTests {
    @Test("initializes with clamped index")
    func initializationClampsIndex() {
        let cards = [Flashcard(front: "A", back: "B"), Flashcard(front: "C", back: "D")]
        let store = FlashcardSessionStore(cards: cards, startIndex: 5)
        #expect(store.index == 1)
        #expect(store.current == cards[1])
    }

    @Test("next wraps when looping")
    func nextWraps() {
        let cards = [Flashcard(front: "A", back: "B")]
        let store = FlashcardSessionStore(cards: cards)
        store.next()
        #expect(store.index == 0)
    }

    @Test("updateCards selects preferred id")
    func updateCardsPrefersMatchingID() {
        let a = Flashcard(front: "A", back: "B")
        let b = Flashcard(front: "C", back: "D")
        let c = Flashcard(front: "E", back: "F")
        let store = FlashcardSessionStore(cards: [a, b, c], startIndex: 1)
        store.updateCards([c, a, b], prefer: b.id)
        #expect(store.current?.id == b.id)
        store.updateCards([], prefer: nil)
        #expect(store.index == 0)
        #expect(store.current == nil)
    }

    @Test("removeCard adjustsIndex")
    func removeCardAdjustsIndex() {
        let cards = [Flashcard(front: "A", back: "B"), Flashcard(front: "C", back: "D")]
        let store = FlashcardSessionStore(cards: cards, startIndex: 1)
        store.removeCard(id: cards[1].id)
        #expect(store.index == 0)
        #expect(store.current?.id == cards[0].id)
        store.removeCard(id: cards[0].id)
        #expect(store.current == nil)
    }
}
