import SwiftUI

struct ErrorTheme {
    let base: Color
    let bg: Color
    let border: Color

    static func theme(for type: ErrorType) -> ErrorTheme {
        let c = type.color
        return ErrorTheme(base: c, bg: c.opacity(0.08), border: c.opacity(0.35))
    }
}
