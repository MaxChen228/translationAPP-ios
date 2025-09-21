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

    static let availableModels: [String] = [
        "gemini-2.5-pro",
        "gemini-2.5-flash"
    ]
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
        correctionModel = ud.string(forKey: keyCorrectionModel) ?? "gemini-2.5-pro"  // High accuracy for correction
        deckGenerationModel = ud.string(forKey: keyDeckGenerationModel) ?? "gemini-2.5-flash"  // Fast for deck generation
        chatResponseModel = ud.string(forKey: keyChatResponseModel) ?? "gemini-2.5-flash"  // Fast for chat response
        researchModel = ud.string(forKey: keyResearchModel) ?? "gemini-2.5-pro"  // High accuracy for research
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
