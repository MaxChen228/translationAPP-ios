import Foundation
import SwiftUI

@MainActor
final class AppSettingsStore: ObservableObject {
    private let keyBanner = "settings.bannerSeconds"
    private let keyModel = "settings.geminiModel"
    private let keyLang = "settings.language"

    @Published var bannerSeconds: Double {
        didSet { UserDefaults.standard.set(bannerSeconds, forKey: keyBanner) }
    }
    @Published var geminiModel: String {
        didSet { UserDefaults.standard.set(geminiModel, forKey: keyModel) }
    }
    @Published var language: String {
        didSet { UserDefaults.standard.set(language, forKey: keyLang) }
    }

    static let availableModels: [String] = [
        "gemini-2.5-pro",
        "gemini-2.5-flash"
    ]
    static let availableLanguages: [(code: String, label: String)] = [
        ("zh", "中文"),
        ("en", "英文")
    ]

    init() {
        let ud = UserDefaults.standard
        let sec = ud.object(forKey: keyBanner) as? Double ?? 2.0
        bannerSeconds = max(0.5, min(10.0, sec))
        geminiModel = (ud.string(forKey: keyModel) ?? "gemini-2.5-pro")
        language = (ud.string(forKey: keyLang) ?? "zh")
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

