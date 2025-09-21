import Foundation

enum PlaybackBuilder {
    // Build a queue for cards starting at index with settings.
    static func buildQueue(cards: [Flashcard], startIndex: Int, settings: TTSSettings) -> [SpeechItem] {
        guard !cards.isEmpty else { return [] }
        var queue: [SpeechItem] = []
        let rate = max(0.3, min(0.6, settings.rate))
        let sGap = settings.segmentGap
        let cGap = settings.cardGap

        for idx in startIndex..<cards.count {
            let card = cards[idx]
            let frontText = card.front
            let backLines = buildBackLines(card.back, fill: settings.variantFill)

            func addFront(isCardEnd: Bool = false) {
                queue.append(SpeechItem(text: frontText, langCode: settings.frontLang, rate: rate, preDelay: 0, postDelay: sGap, cardIndex: idx, face: .front, isCardEnd: isCardEnd))
            }
            func addBack(isCardEnd: Bool = false) {
                for (i, line) in backLines.enumerated() {
                    let post = (i == backLines.count - 1) ? 0 : sGap
                    let isLastBack = (i == backLines.count - 1) && isCardEnd
                    queue.append(SpeechItem(text: line, langCode: settings.backLang, rate: rate, preDelay: i == 0 ? 0 : 0, postDelay: post, cardIndex: (i == 0 && settings.readOrder == .backOnly) ? idx : (i == 0 && settings.readOrder == .backThenFront ? idx : idx), face: .back, isCardEnd: isLastBack))
                }
            }

            switch settings.readOrder {
            case .frontOnly: addFront(isCardEnd: true)
            case .backOnly: addBack(isCardEnd: true)
            case .frontThenBack: addFront(); addBack(isCardEnd: true)
            case .backThenFront: addBack(); queue.append(SpeechItem(text: frontText, langCode: settings.frontLang, rate: rate, preDelay: sGap, postDelay: 0, cardIndex: idx, face: .front, isCardEnd: true))
            }
            // card gap
            if idx != cards.count - 1 {
                queue.append(SpeechItem(text: "", langCode: settings.backLang, rate: rate, preDelay: cGap, postDelay: 0, cardIndex: nil, face: nil, isCardEnd: false))
            }
        }
        return queue
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
