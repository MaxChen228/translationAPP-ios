import Foundation

enum PlaybackBuilder {
    // Build a queue for cards starting at index with settings.
    static func buildQueue(cards: [Flashcard], startIndex: Int, settings: TTSSettings) -> [SpeechItem] {
        guard !cards.isEmpty else { return [] }
        var queue: [SpeechItem] = []
        let order = orderedFields(for: settings)

        for idx in startIndex..<cards.count {
            let card = cards[idx]
            let payloads = makeFieldPayloads(for: card, settings: settings)
            var spokenAny = false

            let activePayloads: [FieldPayload] = order.compactMap { field in
                guard let payload = payloads[field] else { return nil }
                let config = settings.fieldConfig(for: field)
                guard config.enabled, !payload.lines.isEmpty else { return nil }
                return payload
            }

            guard !activePayloads.isEmpty else { continue }

            for (fieldIndex, payload) in activePayloads.enumerated() {
                let isLastField = fieldIndex == activePayloads.count - 1
                let fieldRate = settings.resolvedRate(for: payload.field)
                let fieldGap = settings.resolvedGap(for: payload.field)

                for (lineIndex, line) in payload.lines.enumerated() {
                    let isLastLineInField = lineIndex == payload.lines.count - 1
                    let isCardEnd = isLastField && isLastLineInField
                    let postDelay = isLastLineInField ? fieldGap : settings.segmentGap
                    queue.append(
                        SpeechItem(
                            text: line,
                            langCode: payload.lang,
                            rate: fieldRate,
                            preDelay: lineIndex == 0 ? 0 : 0,
                            postDelay: postDelay,
                            cardIndex: idx,
                            face: payload.face,
                            isCardEnd: isCardEnd
                        )
                    )
                    spokenAny = true
                }
            }

            if spokenAny && idx != cards.count - 1 {
                queue.append(
                    SpeechItem(
                        text: "",
                        langCode: settings.backLang,
                        rate: settings.rate,
                        preDelay: settings.cardGap,
                        postDelay: 0,
                        cardIndex: nil,
                        face: nil,
                        isCardEnd: false
                    )
                )
            }
        }
        return queue
    }

    private struct FieldPayload {
        let field: TTSField
        let lines: [String]
        let lang: String
        let face: SpeechFace
    }

    private static func orderedFields(for settings: TTSSettings) -> [TTSField] {
        switch settings.readOrder {
        case .frontOnly:
            return [.front, .frontNote]
        case .backOnly:
            return [.back, .backNote]
        case .frontThenBack:
            return [.front, .frontNote, .back, .backNote]
        case .backThenFront:
            return [.back, .backNote, .front, .frontNote]
        }
    }

    private static func makeFieldPayloads(for card: Flashcard, settings: TTSSettings) -> [TTSField: FieldPayload] {
        var map: [TTSField: FieldPayload] = [:]

        let trimmedFront = card.front.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFront.isEmpty {
            map[.front] = FieldPayload(field: .front, lines: [trimmedFront], lang: settings.frontLang, face: .front)
        }

        if let note = card.frontNote?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
            map[.frontNote] = FieldPayload(field: .frontNote, lines: [note], lang: settings.frontLang, face: .front)
        }

        let backLines = buildBackLines(card.back, fill: settings.variantFill)
        if !backLines.isEmpty {
            map[.back] = FieldPayload(field: .back, lines: backLines, lang: settings.backLang, face: .back)
        }

        if let backNote = card.backNote?.trimmingCharacters(in: .whitespacesAndNewlines), !backNote.isEmpty {
            map[.backNote] = FieldPayload(field: .backNote, lines: [backNote], lang: settings.backLang, face: .back)
        }

        return map
    }

    // Back variant algorithm: index-aligned combination across groups.
    static func buildBackLines(_ back: String, fill: VariantFill) -> [String] {
        let elements = parseElements(back)
        // Extract groups and determine max length
        var groups: [[String]] = []
        for el in elements {
            if case .group(let g) = el { groups.append(g) }
        }
        let maxLen = groups.map { $0.count }.max() ?? 1
        guard maxLen > 0 else { return [flattenInline(elements)] }
        var lines: [String] = []
        for k in 0..<maxLen {
            var s = ""
            for el in elements {
                switch el {
                case .text(let t): s += t
                case .group(let opts):
                    if k < opts.count { s += opts[k] }
                    else {
                        switch fill {
                        case .random: s += (opts.randomElement() ?? "")
                        case .wrap: s += opts[k % max(1, opts.count)]
                        }
                    }
                }
            }
            lines.append(trimSpaces(s))
        }
        return lines
    }

    // MARK: - Helpers (reuse VariantSyntax semantics)
    private static func parseElements(_ s: String) -> [VariantElement] {
        let std = standardizeSeparators(s)
        return VariantSyntaxParser.parse(std).elements
    }

    private static func standardizeSeparators(_ s: String) -> String {
        var out = ""; var depth = 0
        for ch in s {
            if ch == "(" || ch == "（" { depth += 1; out.append(ch) }
            else if ch == ")" || ch == "）" { depth = max(0, depth - 1); out.append(ch) }
            else if ch == "/" && depth > 0 { out.append("|") }
            else { out.append(ch) }
        }
        return out
    }

    private static func flattenInline(_ elements: [VariantElement]) -> String {
        var out = ""
        for el in elements { if case .text(let t) = el { out += t } else if case .group(let g) = el { out += g.first ?? "" } }
        return trimSpaces(out)
    }

    private static func trimSpaces(_ s: String) -> String {
        s.replacingOccurrences(of: "  ", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
