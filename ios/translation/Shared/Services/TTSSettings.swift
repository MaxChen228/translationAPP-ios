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

enum TTSField: String, CaseIterable, Codable, Identifiable {
    case front
    case frontNote
    case back
    case backNote

    var id: String { rawValue }

    var localizedTitle: String {
        switch self {
        case .front:
            return String(localized: "tts.field.front", defaultValue: "Front")
        case .frontNote:
            return String(localized: "tts.field.frontNote", defaultValue: "Front Note")
        case .back:
            return String(localized: "tts.field.back", defaultValue: "Back")
        case .backNote:
            return String(localized: "tts.field.backNote", defaultValue: "Back Note")
        }
    }
}

struct TTSFieldSettings: Codable, Equatable {
    var enabled: Bool = true
    var rateOverride: Float? = nil
    var gapOverride: Double? = nil
}

struct TTSSettings: Codable, Equatable {
    var readOrder: ReadOrder = .frontThenBack
    var rate: Float = 0.46
    var segmentGap: Double = 0.5
    var cardGap: Double = 1.0
    var frontLang: String = "zh-TW"
    var backLang: String = "en-US"
    var variantFill: VariantFill = .random
    var fieldSettings: [TTSField: TTSFieldSettings] = TTSSettings.makeDefaultFieldSettings()

    func fieldConfig(for field: TTSField) -> TTSFieldSettings {
        fieldSettings[field] ?? TTSFieldSettings()
    }

    mutating func updateField(_ field: TTSField, mutate: (inout TTSFieldSettings) -> Void) {
        var config = fieldSettings[field] ?? TTSFieldSettings()
        mutate(&config)
        fieldSettings[field] = config
    }

    func resolvedRate(for field: TTSField) -> Float {
        let base = rate
        let override = fieldConfig(for: field).rateOverride
        let value = override ?? base
        return max(0.2, min(1.2, value))
    }

    func resolvedGap(for field: TTSField) -> Double {
        let base = segmentGap
        let override = fieldConfig(for: field).gapOverride
        let value = override ?? base
        return max(0, min(5.0, value))
    }

    static func makeDefaultFieldSettings() -> [TTSField: TTSFieldSettings] {
        var dict: [TTSField: TTSFieldSettings] = [:]
        for field in TTSField.allCases {
            dict[field] = TTSFieldSettings()
        }
        return dict
    }
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
    @AppStorage("tts.fieldSettings") private var fieldSettingsData: Data = Data()

    var settings: TTSSettings {
        get {
            TTSSettings(
                readOrder: ReadOrder(rawValue: ro) ?? .frontThenBack,
                rate: Float(rate),
                segmentGap: segGap,
                cardGap: cardGap,
                frontLang: front,
                backLang: back,
                variantFill: VariantFill(rawValue: fill) ?? .random,
                fieldSettings: decodeFieldSettings() ?? TTSSettings.makeDefaultFieldSettings()
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
            persistFieldSettings(newValue.fieldSettings)
            objectWillChange.send()
        }
    }

    private func decodeFieldSettings() -> [TTSField: TTSFieldSettings]? {
        guard !fieldSettingsData.isEmpty else { return nil }
        do {
            return try JSONDecoder().decode([TTSField: TTSFieldSettings].self, from: fieldSettingsData)
        } catch {
            return nil
        }
    }

    private func persistFieldSettings(_ map: [TTSField: TTSFieldSettings]) {
        do {
            let encoded = try JSONEncoder().encode(map)
            fieldSettingsData = encoded
        } catch {
            fieldSettingsData = Data()
        }
    }
}

