import Foundation

struct CorrectionPersistenceState {
    var inputZh: String = ""
    var inputEn: String = ""
    var response: AIResponse? = nil
    var practicedHints: [BankHint] = []
    var showPracticedHints: Bool = false
}

protocol CorrectionPersistence {
    func load() -> CorrectionPersistenceState
    func saveInputZh(_ value: String)
    func saveInputEn(_ value: String)
    func saveResponse(_ response: AIResponse?)
    func saveHints(_ hints: [BankHint])
    func saveShowPracticedHints(_ value: Bool)
    func clearAll()
}

final class UserDefaultsCorrectionPersistence: CorrectionPersistence {
    private let defaults: UserDefaults
    private let keyInputZh: String
    private let keyInputEn: String
    private let keyResponse: String
    private let keyHints: String
    private let keyShowHints: String

    init(workspaceID: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let prefix = "workspace.\(workspaceID)."
        self.keyInputZh = prefix + "inputZh"
        self.keyInputEn = prefix + "inputEn"
        self.keyResponse = prefix + "response"
        self.keyHints = prefix + "practicedHints"
        self.keyShowHints = prefix + "showPracticedHints"
    }

    func load() -> CorrectionPersistenceState {
        var state = CorrectionPersistenceState()
        state.inputZh = defaults.string(forKey: keyInputZh) ?? ""
        state.inputEn = defaults.string(forKey: keyInputEn) ?? ""
        if let data = defaults.data(forKey: keyResponse) {
            state.response = try? JSONDecoder().decode(AIResponse.self, from: data)
        }
        if let data = defaults.data(forKey: keyHints),
           let hints = try? JSONDecoder().decode([BankHint].self, from: data) {
            state.practicedHints = hints
        }
        state.showPracticedHints = defaults.bool(forKey: keyShowHints)
        return state
    }

    func saveInputZh(_ value: String) {
        defaults.set(value, forKey: keyInputZh)
    }

    func saveInputEn(_ value: String) {
        defaults.set(value, forKey: keyInputEn)
    }

    func saveResponse(_ response: AIResponse?) {
        if let response, let data = try? JSONEncoder().encode(response) {
            defaults.set(data, forKey: keyResponse)
        } else {
            defaults.removeObject(forKey: keyResponse)
        }
    }

    func saveHints(_ hints: [BankHint]) {
        guard !hints.isEmpty else {
            defaults.removeObject(forKey: keyHints)
            return
        }
        if let data = try? JSONEncoder().encode(hints) {
            defaults.set(data, forKey: keyHints)
        }
    }

    func saveShowPracticedHints(_ value: Bool) {
        defaults.set(value, forKey: keyShowHints)
    }

    func clearAll() {
        defaults.removeObject(forKey: keyInputZh)
        defaults.removeObject(forKey: keyInputEn)
        defaults.removeObject(forKey: keyResponse)
        defaults.removeObject(forKey: keyHints)
        defaults.removeObject(forKey: keyShowHints)
    }
}
