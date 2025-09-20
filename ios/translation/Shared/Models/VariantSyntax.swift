import SwiftUI

enum VariantElement: Equatable {
    case text(String)
    case group([String])
}

struct VariantPhrase: Equatable {
    var elements: [VariantElement]
    var hasGroup: Bool { elements.contains { if case .group = $0 { return true } else { return false } } }
}

enum VariantSyntaxParser {
    static func parse(_ s: String) -> VariantPhrase {
        var elements: [VariantElement] = []
        var buf = ""
        var i = s.startIndex
        while i < s.endIndex {
            let ch = s[i]
            if ch == "(" || ch == "（" {
                if !buf.isEmpty {
                    elements.append(.text(buf))
                    buf.removeAll(keepingCapacity: true)
                }
                var j = s.index(after: i)
                var group = ""
                var found = false
                while j < s.endIndex {
                    let cj = s[j]
                    if cj == ")" || cj == "）" {
                        found = true
                        break
                    }
                    group.append(cj)
                    j = s.index(after: j)
                }
                if found {
                    let variants = group.split(whereSeparator: { $0 == "|" || $0 == "｜" })
                        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                        .filter { !$0.isEmpty }
                    if !variants.isEmpty {
                        elements.append(.group(variants))
                    }
                    i = s.index(after: j)
                    continue
                } else {
                    buf.append(ch)
                    i = s.index(after: i)
                    continue
                }
            } else {
                buf.append(ch)
                i = s.index(after: i)
            }
        }
        if !buf.isEmpty {
            elements.append(.text(buf))
        }
        return VariantPhrase(elements: mergeAdjacentText(elements))
    }

    private static func mergeAdjacentText(_ arr: [VariantElement]) -> [VariantElement] {
        var out: [VariantElement] = []
        for el in arr {
            if case .text(let s) = el, case .text(let last)? = out.last {
                out.removeLast()
                out.append(.text(last + s))
            } else {
                out.append(el)
            }
        }
        return out
    }
}

struct BracketGroupView: View {
    let options: [String]
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            GeometryReader { geo in
                let w: CGFloat = 8
                let h: CGFloat = geo.size.height
                Path { p in
                    let x0: CGFloat = w - 1
                    let y0: CGFloat = 4
                    let y1: CGFloat = max(h - 4, y0 + 8)
                    p.move(to: CGPoint(x: x0, y: y0))
                    p.addLine(to: CGPoint(x: 1, y: y0))
                    p.move(to: CGPoint(x: x0, y: y0))
                    p.addLine(to: CGPoint(x: x0, y: y1))
                    p.move(to: CGPoint(x: x0, y: y1))
                    p.addLine(to: CGPoint(x: 1, y: y1))
                }
                .stroke(DS.Palette.primary.opacity(0.7), lineWidth: DS.BorderWidth.regular)
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(options.indices, id: \.self) { idx in
                    Text(options[idx])
                        .dsType(DS.Font.body)
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}

struct VariantPhraseView: View {
    let phrase: String
    init(_ phrase: String) { self.phrase = phrase }
    var body: some View {
        let inline = flattenToInlineAB(phrase)
        Text(inline)
            .dsType(DS.Font.body)
            .foregroundStyle(.primary)
    }
}

// Build all combinations by expanding each variant group and keeping connectors inline.
private func buildCombinations(from elements: [VariantElement]) -> [String] {
    var rows: [String] = [""]
    for el in elements {
        switch el {
        case .text(let t):
            rows = rows.map { $0 + t }
        case .group(let opts):
            var next: [String] = []
            next.reserveCapacity(rows.count * max(opts.count, 1))
            for r in rows {
                for o in opts { next.append(r + o) }
            }
            rows = next
        }
    }
    return rows.map { $0.trimmingCharacters(in: .whitespaces) }
}

private struct BracketListView<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            GeometryReader { geo in
                let h = geo.size.height
                Path { p in
                    let x: CGFloat = 8
                    let y0: CGFloat = 4
                    let y1: CGFloat = max(h - 4, y0 + 12)
                    p.move(to: CGPoint(x: x, y: y0))
                    p.addLine(to: CGPoint(x: 2, y: y0))
                    p.move(to: CGPoint(x: x, y: y0))
                    p.addLine(to: CGPoint(x: x, y: y1))
                    p.move(to: CGPoint(x: x, y: y1))
                    p.addLine(to: CGPoint(x: 2, y: y1))
                }
                .stroke(DS.Brand.scheme.babyBlue.opacity(0.8), lineWidth: DS.BorderWidth.regular)
            }
            .frame(width: 12)

            content()
        }
    }
}

struct CombinedVariantsView: View {
    let elements: [VariantElement]
    var body: some View {
        let lines = buildCombinations(from: elements)
        BracketListView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(lines.indices, id: \.self) { i in
                    Text(lines[i])
                        .dsType(DS.Font.body)
                        .foregroundStyle(.primary)
                }
            }
        }
    }
}

// Simplify rendering: replace every (a | b | c) group with (a / b / c) inline.
func flattenToInlineAB(_ s: String) -> String {
    var out = ""
    var i = s.startIndex
    while i < s.endIndex {
        let ch = s[i]
        if ch == "(" || ch == "（" {
            var j = s.index(after: i)
            var group = ""
            var found = false
            while j < s.endIndex {
                let cj = s[j]
                if cj == ")" || cj == "）" { found = true; break }
                group.append(cj)
                j = s.index(after: j)
            }
            if found {
                let parts = group.split(whereSeparator: { $0 == "|" || $0 == "｜" })
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                let joined = parts.joined(separator: " / ")
                out += "(" + joined + ")"
                i = s.index(after: j)
                continue
            } else {
                out.append(ch)
                i = s.index(after: i)
                continue
            }
        } else {
            out.append(ch)
            i = s.index(after: i)
        }
    }
    return out
}
