import SwiftUI

struct AnnotatedText: View {
    let text: String
    let highlights: [Highlight]
    var selectedID: UUID?

    var body: some View {
        let attributed = buildAttributed()
        Text(attributed)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
            .dsType(DS.Font.bodyEmph, lineSpacing: 6, tracking: 0.1)
    }

    private struct Paint: Equatable {
        var color: Color
        var selected: Bool
    }

    private func buildAttributed() -> AttributedString {
        // 建立所有字元邊界索引
        var boundaries: [String.Index] = []
        boundaries.reserveCapacity(text.count + 1)
        var i = text.startIndex
        boundaries.append(i)
        while i < text.endIndex {
            i = text.index(after: i)
            boundaries.append(i)
        }
        if boundaries.isEmpty { return AttributedString("") }

        // 預設不塗色
        var paints: [Paint?] = Array(repeating: nil, count: max(boundaries.count - 1, 0))

        // 依序塗色；重疊時以「選取中」優先，其次保留先到者（穩定）
        for h in highlights {
            let isSelected = (h.id == selectedID)
            let color = h.type.color
            let paint = Paint(color: color, selected: isSelected)

            // 將 String.Index 區間映射到字符索引範圍
            guard let lower = boundaries.firstIndex(of: h.range.lowerBound),
                  let upper = boundaries.firstIndex(of: h.range.upperBound),
                  lower < upper else { continue }
            for idx in lower..<upper {
                if let existing = paints[idx] {
                    if isSelected && !existing.selected {
                        paints[idx] = paint
                    } // 否則保留原有
                } else {
                    paints[idx] = paint
                }
            }
        }

        // 生成連續 run，並施加全域字體屬性（確保使用 Songti SC）
        var result = AttributedString("")
        var runStart = 0
        var current = paints.first ?? nil
        for pos in 1..<boundaries.count {
            let next = paints[pos < paints.count ? pos : paints.count - 1]
            if next?.color != current?.color || next?.selected != current?.selected {
                // 關閉當前 run
                let lower = boundaries[runStart]
                let upper = boundaries[pos]
                let substr = String(text[lower..<upper])
                var piece = AttributedString(substr)
                if let p = current {
                    piece.backgroundColor = p.color.opacity(p.selected ? 0.18 : 0.10)
                }
                result += piece
                // 開啟新 run
                runStart = pos
                current = next
            }
        }

        // 收尾
        if runStart < boundaries.count - 1 {
            let lower = boundaries[runStart]
            let upper = boundaries.last!
            let substr = String(text[lower..<upper])
            var piece = AttributedString(substr)
            if let p = current {
                piece.backgroundColor = p.color.opacity(p.selected ? 0.18 : 0.10)
            }
            result += piece
        }

        // 套用全域字體屬性（Songti SC or fallback）
        var container = AttributeContainer()
        container.font = DS.Font.bodyEmph
        result.mergeAttributes(container)
        return result
    }
}
