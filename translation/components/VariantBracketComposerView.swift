import SwiftUI

// Render a bracket-style composer for phrases with variant groups, e.g.
// (A | B) xyz (C | D)
struct VariantBracketComposerView: View {
    let phrase: String
    @State private var selected: [Int: Int] = [:]
    @State private var normalized: String = ""

    init(_ phrase: String) {
        self.phrase = phrase
    }

    var body: some View {
        let parsed = VariantSyntaxParser.parse(standardizeSeparators(phrase))
        let groups = parsed.elements.enumerated().compactMap { (i, el) -> (idx: Int, opts: [String])? in
            if case .group(let g) = el { return (i, g) } else { return nil }
        }

        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(parsed.elements.indices, id: \.self) { i in
                        switch parsed.elements[i] {
                        case .text(let t):
                            Text(t)
                                .dsType(DS.Font.body)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                        case .group(let options):
                            BracketOptionsColumn(options: options, selection: Binding(
                                get: { selected[i] ?? 0 },
                                set: { selected[i] = $0 }
                            ))
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            // Current composed line + copy
            HStack(spacing: 8) {
                Text(currentCombinedText(elements: parsed.elements))
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                Button { copyCurrent(parsed.elements) } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(DSSecondaryButtonCompact())
                .accessibilityLabel("複製目前組合")
            }
        }
        .onAppear { ensureSelection(groups: groups) }
        .onChange(of: phrase) { _ in ensureSelection(groups: groups) }
    }

    private func copyCurrent(_ elements: [VariantElement]) {
        #if canImport(UIKit)
        let str = currentCombinedText(elements: elements)
        UIPasteboard.general.string = str
        #endif
    }

    private func currentCombinedText(elements: [VariantElement]) -> String {
        var out = ""
        for (i, el) in elements.enumerated() {
            switch el {
            case .text(let s): out += s
            case .group(let g):
                let idx = min(max(0, selected[i] ?? 0), max(0, g.count - 1))
                if g.indices.contains(idx) { out += g[idx] }
            }
        }
        return out.replacingOccurrences(of: "  ", with: " ")
    }
}

private struct BracketOptionsColumn: View {
    let options: [String]
    @Binding var selection: Int

    var body: some View {
        ThinBracketContainer {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(options.indices, id: \.self) { idx in
                    let isSel = idx == selection
                    Button {
                        selection = idx
                        Haptics.success()
                    } label: {
                        Text(options[idx])
                            .dsType(DS.Font.body)
                            .foregroundStyle(.primary)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                Capsule().fill(isSel ? DS.Palette.surface : .clear)
                            )
                            .overlay(
                                Capsule().stroke(DS.Palette.border.opacity(isSel ? 0.45 : 0.18), lineWidth: isSel ? 1 : DS.Metrics.hairline)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// Replace '/' with '|' inside parentheses so the parser can split variants.
private func standardizeSeparators(_ s: String) -> String {
    var out = ""
    var depth = 0
    for ch in s { 
        if ch == "(" || ch == "（" { depth += 1; out.append(ch) }
        else if ch == ")" || ch == "）" { depth = max(0, depth - 1); out.append(ch) }
        else if ch == "/" && depth > 0 { out.append("|") }
        else { out.append(ch) }
    }
    return out
}

private extension VariantBracketComposerView {
    func ensureSelection(groups: [(idx: Int, opts: [String])]) {
        for (i, g) in groups {
            if selected[i] == nil { selected[i] = 0 }
            if let val = selected[i], val >= g.count { selected[i] = max(0, g.count - 1) }
        }
    }
}

// Local bracket container to avoid depending on file-private views.
private struct ThinBracketContainer<Content: View>: View {
    let content: () -> Content
    init(@ViewBuilder content: @escaping () -> Content) { self.content = content }
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            GeometryReader { geo in
                let h = max(geo.size.height, 20)
                let x: CGFloat = 8
                let y0: CGFloat = 4
                let y1: CGFloat = max(h - 4, y0 + 12)
                Path { p in
                    p.move(to: CGPoint(x: x, y: y0))
                    p.addLine(to: CGPoint(x: 2, y: y0))
                    p.move(to: CGPoint(x: x, y: y0))
                    p.addLine(to: CGPoint(x: x, y: y1))
                    p.move(to: CGPoint(x: x, y: y1))
                    p.addLine(to: CGPoint(x: 2, y: y1))
                }
                .stroke(DS.Brand.scheme.babyBlue.opacity(0.8), lineWidth: 1)
            }
            .frame(width: 12)

            content()
        }
    }
}
