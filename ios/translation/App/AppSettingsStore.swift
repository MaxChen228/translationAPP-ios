import Foundation
import SwiftUI

@MainActor
final class AppSettingsStore: ObservableObject {
    private let keyBanner = "settings.bannerSeconds"
    private let keyLang = "settings.language"

    // Individual model settings
    private let keyCorrectionModel = "settings.correctionModel"
    private let keyDeckGenerationModel = "settings.deckGenerationModel"
    private let keyChatResponseModel = "settings.chatResponseModel"
    private let keyResearchModel = "settings.researchModel"

    @Published var bannerSeconds: Double {
        didSet { UserDefaults.standard.set(bannerSeconds, forKey: keyBanner) }
    }
    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: keyLang) }
    }

    // Individual AI model settings
    @Published var correctionModel: String {
        didSet { UserDefaults.standard.set(correctionModel, forKey: keyCorrectionModel) }
    }
    @Published var deckGenerationModel: String {
        didSet { UserDefaults.standard.set(deckGenerationModel, forKey: keyDeckGenerationModel) }
    }
    @Published var chatResponseModel: String {
        didSet { UserDefaults.standard.set(chatResponseModel, forKey: keyChatResponseModel) }
    }
    @Published var researchModel: String {
        didSet { UserDefaults.standard.set(researchModel, forKey: keyResearchModel) }
    }

    struct AIModelOption: Identifiable {
        let value: String
        let labelKey: LocalizedStringKey

        var id: String { value }
    }

    static let availableModels: [AIModelOption] = [
        AIModelOption(value: "gemini-2.5-flash-lite", labelKey: "settings.aiModels.option.lite"),
        AIModelOption(value: "gemini-2.5-flash", labelKey: "settings.aiModels.option.flash"),
        AIModelOption(value: "gemini-2.5-pro", labelKey: "settings.aiModels.option.pro")
    ]

    private static let availableModelValues: Set<String> = Set(availableModels.map(\.value))
    static var availableLanguages: [(code: String, label: String)] {
        [
            ("zh", String(localized: "settings.language.zh")),
            ("en", String(localized: "settings.language.en"))
        ]
    }

    init() {
        let ud = UserDefaults.standard
        let sec = ud.object(forKey: keyBanner) as? Double ?? 2.0
        bannerSeconds = max(0.5, min(10.0, sec))
        language = (ud.string(forKey: keyLang) ?? "zh")

        // Initialize individual model settings with smart defaults
        correctionModel = AppSettingsStore.validatedModel(ud.string(forKey: keyCorrectionModel), fallback: "gemini-2.5-flash")  // Default to mid-tier speed/quality
        deckGenerationModel = AppSettingsStore.validatedModel(ud.string(forKey: keyDeckGenerationModel), fallback: "gemini-2.5-flash")  // Default to mid-tier speed/quality
        chatResponseModel = AppSettingsStore.validatedModel(ud.string(forKey: keyChatResponseModel), fallback: "gemini-2.5-flash")  // Default to mid-tier speed/quality
        researchModel = AppSettingsStore.validatedModel(ud.string(forKey: keyResearchModel), fallback: "gemini-2.5-flash")  // Default to mid-tier speed/quality
    }

    var deviceID: String { DeviceID.current }

    var appVersion: String {
        let ver = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        if ver.isEmpty { return build }
        if build.isEmpty { return ver }
        return "\(ver) (\(build))"
    }
}

private extension AppSettingsStore {
    static func validatedModel(_ stored: String?, fallback: String) -> String {
        guard let stored, availableModelValues.contains(stored) else { return fallback }
        return stored
    }
}
