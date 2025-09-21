import Foundation
import SwiftUI

enum ReadOrder: String, CaseIterable, Codable, Identifiable {
    case frontOnly = "front"
    case backOnly = "back"
    case frontThenBack = "frontThenBack"
    case backThenFront = "backThenFront"

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .frontOnly: return "tts.order.front"
        case .backOnly: return "tts.order.back"
        case .frontThenBack: return "tts.order.frontThenBack"
        case .backThenFront: return "tts.order.backThenFront"
        }
    }
}

enum VariantFill: String, CaseIterable, Codable, Identifiable {
    case random, wrap

    var id: String { rawValue }

    var displayName: LocalizedStringKey {
        switch self {
        case .random: return "tts.fill.random"
        case .wrap: return "tts.fill.wrap"
        }
    }
}

struct TTSSettings: Codable, Equatable {
    var readOrder: ReadOrder = .frontThenBack
    var rate: Float = 0.46
    var segmentGap: Double = 0.5
    var cardGap: Double = 1.0
    var frontLang: String = "zh-TW"
    var backLang: String = "en-US"
    var variantFill: VariantFill = .random
}

@MainActor
final class TTSSettingsStore: ObservableObject {
    @AppStorage("tts.readOrder") private var ro: String = ReadOrder.frontThenBack.rawValue
    @AppStorage("tts.rate") private var rate: Double = 0.46
    @AppStorage("tts.segmentGap") private var segGap: Double = 0.5
    @AppStorage("tts.cardGap") private var cardGap: Double = 1.0
    @AppStorage("tts.frontLang") private var front: String = "zh-TW"
    @AppStorage("tts.backLang") private var back: String = "en-US"
    @AppStorage("tts.variantFill") private var fill: String = VariantFill.random.rawValue

    var settings: TTSSettings {
        get {
            TTSSettings(
                readOrder: ReadOrder(rawValue: ro) ?? .frontThenBack,
                rate: Float(rate),
                segmentGap: segGap,
                cardGap: cardGap,
                frontLang: front,
                backLang: back,
                variantFill: VariantFill(rawValue: fill) ?? .random
            )
        }
        set {
            ro = newValue.readOrder.rawValue
            rate = Double(newValue.rate)
            segGap = newValue.segmentGap
            cardGap = newValue.cardGap
            front = newValue.frontLang
            back = newValue.backLang
            fill = newValue.variantFill.rawValue
            objectWillChange.send()
        }
    }
}

