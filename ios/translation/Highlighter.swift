import Foundation

// 將錯誤項目以「逐字配對」方式映射到使用者英文文字區間
enum Highlighter {
    // 基本設定：是否忽略大小寫、是否壓縮空白（此處保持簡單，預設只忽略大小寫）
    private static let ignoreCase = true

    static func computeHighlights(text: String, errors: [ErrorItem]) -> [Highlight] {
        guard !text.isEmpty else { return [] }

        var highlights: [Highlight] = []
        let base = normalize(text)

        // 建立原始到標準化索引的對應（此處大小寫忽略不改長度，故直接用原字串範圍）
        for err in errors {
            let spanNorm = normalize(err.span)
            guard !spanNorm.isEmpty else { continue }

            if let range = findRange(in: text, baseNorm: base, spanNorm: spanNorm, hints: err.hints) {
                let highlight = Highlight(id: err.id, range: range, type: err.type)
                highlights.append(highlight)
            }
        }

        return highlights
    }

    // 對外開放：取得單一錯誤在文字中的 Range
    static func range(for error: ErrorItem, in text: String) -> Range<String.Index>? {
        let base = normalize(text)
        let spanNorm = normalize(error.span)
        return findRange(in: text, baseNorm: base, spanNorm: spanNorm, hints: error.hints)
    }

    // 在修正版文字中尋找建議字詞的區間
    static func suggestionRange(for error: ErrorItem, in corrected: String) -> Range<String.Index>? {
        guard let suggestion = error.suggestion, !suggestion.isEmpty else { return nil }
        let base = normalize(corrected)
        let needle = normalize(suggestion)
        if let occ = error.hints?.occurrence, occ > 0 {
            if let rNorm = nthOccurrenceRangeNormalized(baseNorm: base, subNorm: needle, n: occ) {
                return mapNormalizedRangeToOriginal(original: corrected, baseNorm: base, normRange: rNorm)
            }
        }
        if let r = base.range(of: needle) {
            return mapNormalizedRangeToOriginal(original: corrected, baseNorm: base, normRange: r)
        }
        return nil
    }

    // 在修正版中計算高亮：優先以 suggestion 搜尋，否則回退不標註
    static func computeHighlightsInCorrected(text corrected: String, errors: [ErrorItem]) -> [Highlight] {
        guard !corrected.isEmpty else { return [] }
        let base = normalize(corrected)
        var used: [Range<String.Index>] = []
        var highlights: [Highlight] = []

        func isOverlapping(_ r: Range<String.Index>) -> Bool {
            return used.contains(where: { !(r.upperBound <= $0.lowerBound || r.lowerBound >= $0.upperBound) })
        }

        for err in errors {
            guard let suggestion = err.suggestion, !suggestion.isEmpty else { continue }
            let needle = normalize(suggestion)
            // 若提供 occurrence，優先使用；否則從左至右找第一個未被佔用的匹配
            if let occ = err.hints?.occurrence, occ > 0 {
                if let rNorm = nthOccurrenceRangeNormalized(baseNorm: base, subNorm: needle, n: occ),
                   let r = mapNormalizedRangeToOriginal(original: corrected, baseNorm: base, normRange: rNorm),
                   !isOverlapping(r) {
                    used.append(r)
                    highlights.append(Highlight(id: err.id, range: r, type: err.type))
                    continue
                }
            }

            var start = base.startIndex
            while start < base.endIndex, let rNorm = base.range(of: needle, range: start..<base.endIndex) {
                if let r = mapNormalizedRangeToOriginal(original: corrected, baseNorm: base, normRange: rNorm), !isOverlapping(r) {
                    used.append(r)
                    highlights.append(Highlight(id: err.id, range: r, type: err.type))
                    break
                }
                start = rNorm.upperBound
            }
        }

        return highlights
    }

    private static func normalize(_ s: String) -> String {
        if ignoreCase {
            return s.lowercased()
        }
        return s
    }

    private static func findRange(
        in original: String,
        baseNorm: String,
        spanNorm: String,
        hints: ErrorHints?
    ) -> Range<String.Index>? {
        // 若有 before/after，嘗試以上下文拼接匹配
        if let h = hints, (h.before != nil || h.after != nil) {
            let before = normalize(h.before ?? "")
            let after = normalize(h.after ?? "")
            let needle = before + spanNorm + after
            if let whole = rangeOfNormalized(sub: needle, in: baseNorm) {
                // 直接在 whole 範圍中再次尋找 span，避免以字數裁切造成邊界誤差
                if let inner = baseNorm.range(of: spanNorm, range: whole) {
                    return mapNormalizedRangeToOriginal(original: original, baseNorm: baseNorm, normRange: inner)
                }
                // 後備：以裁切方式回推（理論上不會走到這裡，但保留容錯）
                let startOffset = before.count
                let endOffset = after.count
                if let spanRange = sliceOriginalRange(original: original, baseNorm: baseNorm, wholeNormRange: whole, trimHead: startOffset, trimTail: endOffset) {
                    return spanRange
                }
            }
        }

        // 若指定第 N 次出現
        if let occ = hints?.occurrence, occ > 0 {
            if let r = nthOccurrenceRange(original: original, baseNorm: baseNorm, spanNorm: spanNorm, n: occ) {
                return r
            }
        }

        // 預設使用第一個匹配
        if let r = rangeOfNormalized(sub: spanNorm, in: baseNorm) {
            return mapNormalizedRangeToOriginal(original: original, baseNorm: baseNorm, normRange: r)
        }

        return nil
    }

    // 在標準化字串中找子字串的 Range（以 String.Index 對 baseNorm）
    private static func rangeOfNormalized(sub: String, in baseNorm: String) -> Range<String.Index>? {
        return baseNorm.range(of: sub)
    }

    // 找第 n 次出現
    private static func nthOccurrenceRange(original: String, baseNorm: String, spanNorm: String, n: Int) -> Range<String.Index>? {
        var start = baseNorm.startIndex
        var count = 0
        while start < baseNorm.endIndex,
              let r = baseNorm.range(of: spanNorm, range: start..<baseNorm.endIndex) {
            count += 1
            if count == n {
                return mapNormalizedRangeToOriginal(original: original, baseNorm: baseNorm, normRange: r)
            }
            start = r.upperBound
        }
        return nil
    }

    private static func nthOccurrenceRangeNormalized(baseNorm: String, subNorm: String, n: Int) -> Range<String.Index>? {
        var start = baseNorm.startIndex
        var count = 0
        while start < baseNorm.endIndex,
              let r = baseNorm.range(of: subNorm, range: start..<baseNorm.endIndex) {
            count += 1
            if count == n { return r }
            start = r.upperBound
        }
        return nil
    }

    // 將 baseNorm 的區間映射回 original 同位置（忽略大小寫不改動長度與切片位置）
    private static func mapNormalizedRangeToOriginal(original: String, baseNorm: String, normRange: Range<String.Index>) -> Range<String.Index>? {
        // 由於大小寫轉換不改變字元數與切片位置，此處可直接用同樣的下標索引範圍
        // 但需確保 original 與 baseNorm 是對同一序列的索引空間（Swift 不允許跨字串索引）
        // 因此這裡改以偏移量實作
        let lower = baseNorm.distance(from: baseNorm.startIndex, to: normRange.lowerBound)
        let upper = baseNorm.distance(from: baseNorm.startIndex, to: normRange.upperBound)
        if let lowerIdx = original.index(original.startIndex, offsetBy: lower, limitedBy: original.endIndex),
           let upperIdx = original.index(original.startIndex, offsetBy: upper, limitedBy: original.endIndex),
           lowerIdx <= upperIdx {
            return lowerIdx..<upperIdx
        }
        return nil
    }

    // 從帶有前後文的整段區間切到 span 區間
    private static func sliceOriginalRange(
        original: String,
        baseNorm: String,
        wholeNormRange: Range<String.Index>,
        trimHead: Int,
        trimTail: Int
    ) -> Range<String.Index>? {
        guard let whole = mapNormalizedRangeToOriginal(original: original, baseNorm: baseNorm, normRange: wholeNormRange) else {
            return nil
        }
        let lower = original.index(whole.lowerBound, offsetBy: trimHead, limitedBy: whole.upperBound) ?? whole.lowerBound
        let upper = original.index(whole.upperBound, offsetBy: -trimTail, limitedBy: whole.lowerBound) ?? whole.upperBound
        return lower..<max(lower, upper)
    }
}
