import Foundation
import SwiftUI

struct Flashcard: Identifiable, Codable, Equatable {
    let id: UUID
    var front: String
    var frontNote: String?
    var back: String
    var backNote: String?

    init(id: UUID = UUID(), front: String, back: String, frontNote: String? = nil, backNote: String? = nil) {
        self.id = id
        self.front = front
        self.frontNote = frontNote
        self.back = back
        self.backNote = backNote
    }
}

enum AnnotateFeedback: Equatable {
    case familiar
    case unfamiliar

    var color: Color {
        switch self {
        case .familiar: return DS.Palette.success
        case .unfamiliar: return DS.Palette.warning
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .familiar: return "flashcards.annotate.familiar"
        case .unfamiliar: return "flashcards.annotate.unfamiliar"
        }
    }
}
