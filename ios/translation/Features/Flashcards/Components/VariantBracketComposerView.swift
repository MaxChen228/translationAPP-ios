import SwiftUI

// Render a bracket-style composer for phrases with variant groups, e.g.
// (A | B) xyz (C | D)
struct VariantBracketComposerView: View {
    let phrase: String
    @State private var selected: [Int: Int] = [:]
    @State private var normalized: String = ""
    var onComposedChange: ((String) -> Void)? = nil
    @EnvironmentObject private var bannerCenter: BannerCenter
    @Environment(\.locale) private var locale

    init(_ phrase: String, onComposedChange: ((String) -> Void)? = nil) {
        self.phrase = phrase
        self.onComposedChange = onComposedChange
    }

    var body: some View {
        let parsed0 = VariantSyntaxParser.parse(standardizeSeparators(phrase))
        let parsed = transformByFactoring(parsed0)
        let groups = parsed.elements.enumerated().compactMap { (i, el) -> (idx: Int, opts: [String])? in
            if case .group(let g) = el { return (i, g) } else { return nil }
        }

        VStack(alignment: .leading, spacing: 10) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 10) {
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
                                set: { newVal in
                                    selected[i] = newVal
                                    let text = currentCombinedText(elements: parsed.elements)
                                    onComposedChange?(text)
                                }
                            ))
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            // Current composed line + copy (左側排版，避免與播放鍵重疊)
            HStack(spacing: 10) {
                Button { copyCurrent(parsed.elements) } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(DSSecondaryButtonCompact())
                .accessibilityLabel(Text("a11y.copyCurrentComposition"))

                Text(currentCombinedText(elements: parsed.elements))
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { ensureSelection(groups: groups); onComposedChange?(currentCombinedText(elements: parsed.elements)) }
        .onChange(of: phrase) { _, _ in ensureSelection(groups: groups); onComposedChange?(currentCombinedText(elements: parsed.elements)) }
        .padding(.bottom, 52) // 預留右下角播放鍵空間，避免重疊
    }

    private func copyCurrent(_ elements: [VariantElement]) {
        #if canImport(UIKit)
        let str = currentCombinedText(elements: elements)
        UIPasteboard.general.string = str
        Haptics.success()
        bannerCenter.show(title: String(localized: "action.copied", locale: locale), subtitle: str)
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
                            .fontWeight(isSel ? .semibold : .regular)
                            .foregroundStyle(.primary)
                            .padding(.vertical, 3)
                            .padding(.horizontal, 6)
                            .background(
                                Capsule().fill(DS.Palette.surface.opacity(isSel ? 0.06 : 0))
                            )
                            .overlay(
                                Capsule().stroke(DS.Palette.border.opacity(isSel ? 0.45 : 0.18), lineWidth: isSel ? DS.BorderWidth.regular : DS.BorderWidth.hairline)
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
    func transformByFactoring(_ parsed: VariantPhrase) -> VariantPhrase {
        var out: [VariantElement] = []
        for el in parsed.elements {
            switch el {
            case .text:
                out.append(el)
            case .group(let opts):
                let trimmed = opts.map { $0.trimmingCharacters(in: .whitespaces) }
                let cp = factoredCommonPrefix(trimmed)
                let cs = factoredCommonSuffix(trimmed)
                if !cp.isEmpty { out.append(.text(cp)) }
                let core = trimmed.map { stripPrefixSuffix($0, prefix: cp, suffix: cs) }
                out.append(.group(core))
                if !cs.isEmpty { out.append(.text(cs)) }
            }
        }
        return VariantPhrase(elements: mergeAdjacentTextElements(out))
    }

    func factoredCommonPrefix(_ arr: [String]) -> String {
        guard let first = arr.first, arr.count > 1 else { return "" }
        var cp = first
        for s in arr.dropFirst() {
            cp = commonPrefix(cp, s)
            if cp.isEmpty { break }
        }
        // 回退到詞邊界（最後一個空白或標點之後）
        if let idx = cp.lastIndex(where: { $0.isWhitespace || ",.;:!?".contains($0) }) {
            let end = cp.index(after: idx)
            return String(cp[..<end])
        }
        return ""
    }

    func factoredCommonSuffix(_ arr: [String]) -> String {
        guard let first = arr.first, arr.count > 1 else { return "" }
        var cs = first
        for s in arr.dropFirst() {
            cs = commonSuffix(cs, s)
            if cs.isEmpty { break }
        }
        // 取從第一個空白或標點開始的尾段，避免切在詞中間
        if let i = cs.firstIndex(where: { $0.isWhitespace || ",.;:!?".contains($0) }) {
            return String(cs[i...])
        }
        return ""
    }

    func commonPrefix(_ a: String, _ b: String) -> String {
        let ac = Array(a), bc = Array(b)
        var i = 0
        while i < ac.count && i < bc.count && ac[i] == bc[i] { i += 1 }
        return String(ac[0..<i])
    }

    func commonSuffix(_ a: String, _ b: String) -> String {
        let ac = Array(a), bc = Array(b)
        var ia = ac.count - 1, ib = bc.count - 1
        var len = 0
        while ia >= 0 && ib >= 0 && ac[ia] == bc[ib] { ia -= 1; ib -= 1; len += 1 }
        if len == 0 { return "" }
        return String(ac[(ac.count - len)...])
    }

    func stripPrefixSuffix(_ s: String, prefix: String, suffix: String) -> String {
        var out = s
        if !prefix.isEmpty, out.hasPrefix(prefix) { out.removeFirst(prefix.count) }
        if !suffix.isEmpty, out.hasSuffix(suffix) { out.removeLast(suffix.count) }
        return out.trimmingCharacters(in: .whitespaces)
    }
    
    func mergeAdjacentTextElements(_ arr: [VariantElement]) -> [VariantElement] {
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
        HStack(alignment: .top, spacing: 8) {
            GeometryReader { geo in
                let h = max(geo.size.height, 20)
                let x: CGFloat = 7
                let y0: CGFloat = 3
                let y1: CGFloat = max(h - 3, y0 + 12)
                ZStack(alignment: .topLeading) {
                    Path { p in
                        p.move(to: CGPoint(x: x, y: y0))
                        p.addLine(to: CGPoint(x: 2, y: y0))
                        p.move(to: CGPoint(x: x, y: y0))
                        p.addLine(to: CGPoint(x: x, y: y1))
                        p.move(to: CGPoint(x: x, y: y1))
                        p.addLine(to: CGPoint(x: 2, y: y1))
                    }
                    .stroke(DS.Brand.scheme.babyBlue.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.thin)

                    Text("…")
                        .font(DS.Font.tiny)
                        .foregroundStyle(DS.Palette.border.opacity(DS.Opacity.strong))
                        .offset(x: 1, y: -2)
                }
            }
            .frame(width: 10)

            content()
        }
    }
}
