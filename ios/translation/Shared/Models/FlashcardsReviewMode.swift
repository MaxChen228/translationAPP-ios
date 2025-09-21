import Foundation
import SwiftUI

enum FlashcardsReviewMode: String, CaseIterable, Codable {
    case browse = "browse"
    case annotate = "annotate"

    var labelKey: LocalizedStringKey {
        switch self {
        case .browse: return "flashcards.mode.browse"
        case .annotate: return "flashcards.mode.annotate"
        }
    }

    var storageValue: String { rawValue }

    static func fromStorage(_ value: String) -> FlashcardsReviewMode {
        if let mode = FlashcardsReviewMode(rawValue: value) { return mode }
        switch value {
        case LegacyValues.zhBrowse: return .browse
        case LegacyValues.zhAnnotate: return .annotate
        default: return .browse
        }
    }

    private enum LegacyValues {
        static let zhBrowse = "瀏覽"
        static let zhAnnotate = "標注"
    }
}
