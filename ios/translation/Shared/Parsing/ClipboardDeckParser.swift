import Foundation

/// Represents the result of validating clipboard content for a Deep Research import.
enum ClipboardDeckParseState: Equatable {
    case notMatched
    case success(ChatResearchDeck)
    case failure(String)
}

struct ClipboardDeckParser {
    private let headerPrefix = "### Translation.DeepResearch"
    private let decoder: JSONDecoder

    init(decoder: JSONDecoder = .init()) {
        self.decoder = decoder
        self.decoder.dateDecodingStrategy = .iso8601
        self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func validate(_ text: String) -> ClipboardDeckParseState {
        let normalized = normalize(text)
        guard let payloadText = extractPayload(from: normalized) else {
            return .notMatched
        }

        do {
            let deck = try parsePayload(payloadText)
            return .success(deck)
        } catch {
            return .failure(error.localizedDescription)
        }
    }

    func parse(_ text: String) throws -> ChatResearchDeck {
        let normalized = normalize(text)
        guard let payloadText = extractPayload(from: normalized) else {
            throw ParserError.missingHeader
        }
        return try parsePayload(payloadText)
    }

    private func normalize(_ text: String) -> String {
        var trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```") else { return trimmed }

        // Strip opening fence and optional language tag (e.g., ```json)
        trimmed.removeFirst(3)
        trimmed = trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
        if let newline = trimmed.firstIndex(of: "\n") {
            let language = trimmed[..<newline]
            if language.allSatisfy({ $0.isLetter || $0 == "-" }) {
                let contentStart = trimmed.index(after: newline)
                trimmed = String(trimmed[contentStart...])
            }
        }

        // Drop trailing fence if present
        if let fenceRange = trimmed.range(of: "```", options: .backwards) {
            trimmed = String(trimmed[..<fenceRange.lowerBound])
        }

        return trimmed.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractPayload(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard trimmed.hasPrefix(headerPrefix) else { return nil }

        guard let newlineRange = trimmed.range(of: "\n") else { return "" }
        let afterHeader = trimmed[newlineRange.upperBound...]
        let payload = afterHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(payload)
    }

    private func parsePayload(_ text: String) throws -> ChatResearchDeck {
        let payload: ClipboardDeckPayload
        do {
            payload = try decoder.decode(ClipboardDeckPayload.self, from: Data(text.utf8))
        } catch {
            throw ParserError.invalidJSON(error)
        }

        let deckName = payload.deckName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !deckName.isEmpty else { throw ParserError.missingDeckName }
        guard !payload.cards.isEmpty else { throw ParserError.emptyCards }

        let cards: [Flashcard] = try payload.cards.map { card in
            let front = card.front.trimmingCharacters(in: .whitespacesAndNewlines)
            let back = card.back.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !front.isEmpty else { throw ParserError.invalidCard("front") }
            guard !back.isEmpty else { throw ParserError.invalidCard("back") }
            return Flashcard(front: front, back: back, frontNote: card.frontNote?.nilIfEmpty, backNote: card.backNote?.nilIfEmpty)
        }

        let generatedAt = payload.generatedAt ?? Date()
        return ChatResearchDeck(name: deckName, cards: cards, generatedAt: generatedAt)
    }
}

private extension String {
    var nilIfEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct ClipboardDeckPayload: Decodable {
    let deckName: String?
    let generatedAt: Date?
    let cards: [ClipboardDeckCardPayload]
}

private struct ClipboardDeckCardPayload: Decodable {
    let front: String
    let back: String
    let frontNote: String?
    let backNote: String?
}

private enum ParserError: LocalizedError {
    case missingHeader
    case invalidJSON(Error)
    case missingDeckName
    case emptyCards
    case invalidCard(String)

    var errorDescription: String? {
        switch self {
        case .missingHeader:
            return String(localized: "chat.clipboard.error.missingHeader")
        case .invalidJSON(let error):
            return String(format: String(localized: "chat.clipboard.error.invalidJSON"), (error as NSError).localizedDescription)
        case .missingDeckName:
            return String(localized: "chat.clipboard.error.missingDeckName")
        case .emptyCards:
            return String(localized: "chat.clipboard.error.emptyCards")
        case .invalidCard(let field):
            return String(format: String(localized: "chat.clipboard.error.invalidCard"), localizedFieldName(field))
        }
    }

    private func localizedFieldName(_ field: String) -> String {
        switch field.lowercased() {
        case "front":
            return String(localized: "chat.clipboard.error.field.front")
        case "back":
            return String(localized: "chat.clipboard.error.field.back")
        default:
            return field
        }
    }
}
