import SwiftUI
import UIKit

/// Text measurement and layout utilities for morphing annotated text components
struct TextMeasurement {

    /// Measures the height needed to display both original and corrected text
    /// Returns the maximum height of the two texts
    static func measureHeight(original: String, corrected: String, font: UIFont, lineSpacing: CGFloat, width: CGFloat) -> CGFloat {
        // If width is extremely small (first pass), return a conservative single-line height
        let minLine = ceil(font.lineHeight + lineSpacing)
        if width < 50 { return max(minLine, 30) }

        func height(for text: String) -> CGFloat {
            let p = NSMutableParagraphStyle()
            p.lineSpacing = lineSpacing
            let attr = NSAttributedString(string: text, attributes: [.font: font, .paragraphStyle: p])
            var rect = attr.boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                       options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
            rect.size.height = ceil(rect.size.height) + 2 // small safety padding
            return max(rect.size.height, minLine)
        }

        return max(height(for: original), height(for: corrected))
    }

    /// Computes bounding rectangles for each highlight in the given text
    /// Uses TextKit layout to determine accurate text positioning
    static func computeRects(in textView: UITextView, text: String, highlights: [Highlight]) -> [UUID: [CGRect]] {
        guard textView.bounds.width > 0 && textView.bounds.height > 0 else { return [:] }
        let lm = textView.layoutManager
        let tc = textView.textContainer

        var result: [UUID: [CGRect]] = [:]

        for h in highlights {
            let range = NSRange(h.range, in: text)
            // Convert to glyph range
            let glyphRange = lm.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
            var rects: [CGRect] = []
            lm.enumerateEnclosingRects(forGlyphRange: glyphRange, withinSelectedGlyphRange: NSRange(location: NSNotFound, length: 0), in: tc) { r, _ in
                // Convert from container coords to view coords
                // UITextView's text is inset by textContainerInset and lineFragmentPadding already set to 0
                // When scroll is enabled and content is shorter, contentOffset will be zero (top-aligned).
                // Translate by inset only.
                var converted = r.offsetBy(dx: textView.textContainerInset.left - textView.contentOffset.x,
                                          dy: textView.textContainerInset.top - textView.contentOffset.y)
                // Make highlight tighter to text by shrinking vertically a bit
                let lineHeight = textView.font?.lineHeight ?? converted.height
                let shrink = max(1, min(3, lineHeight * 0.12))
                converted = converted.insetBy(dx: 0, dy: shrink)
                rects.append(converted.integral)
            }
            result[h.id] = rects
        }

        let used = lm.usedRect(for: tc)
        AppLog.uiDebug("[TextMeasurement.computeRects] used.h=\(used.height) inset=\(textView.textContainerInset) offset=\(textView.contentOffset) rectsCount=\(result.values.reduce(0){$0+$1.count})")
        return result
    }

    /// Creates a mapping from highlight IDs to their display colors
    static func colorsMap(for highlights: [Highlight]) -> [UUID: UIColor] {
        var map: [UUID: UIColor] = [:]
        for h in highlights {
            map[h.id] = UIColor(h.type.color)
        }
        return map
    }
}