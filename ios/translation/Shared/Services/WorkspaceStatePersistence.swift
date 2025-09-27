import Foundation

enum WorkspaceStateKey: String, CaseIterable {
    case inputZh
    case inputEn
    case response
    case practicedHints
    case showPracticedHints
    case resultSaved
}

protocol WorkspaceStatePersisting {
    func readString(_ key: WorkspaceStateKey) -> String?
    func writeString(_ value: String?, key: WorkspaceStateKey)

    func readData(_ key: WorkspaceStateKey) -> Data?
    func writeData(_ data: Data?, key: WorkspaceStateKey)

    func readBool(_ key: WorkspaceStateKey) -> Bool
    func writeBool(_ value: Bool, key: WorkspaceStateKey)

    func remove(_ key: WorkspaceStateKey)
    func removeAll(_ keys: [WorkspaceStateKey])
}

final class DefaultsWorkspaceStatePersistence: WorkspaceStatePersisting {
    private let prefix: String
    private let defaults: UserDefaults

    init(workspaceID: String, defaults: UserDefaults = .standard) {
        self.prefix = "workspace.\(workspaceID)."
        self.defaults = defaults
    }

    func readString(_ key: WorkspaceStateKey) -> String? {
        defaults.string(forKey: namespaced(key))
    }

    func writeString(_ value: String?, key: WorkspaceStateKey) {
        let key = namespaced(key)
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func readData(_ key: WorkspaceStateKey) -> Data? {
        defaults.data(forKey: namespaced(key))
    }

    func writeData(_ data: Data?, key: WorkspaceStateKey) {
        let key = namespaced(key)
        if let data {
            defaults.set(data, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }

    func readBool(_ key: WorkspaceStateKey) -> Bool {
        defaults.bool(forKey: namespaced(key))
    }

    func writeBool(_ value: Bool, key: WorkspaceStateKey) {
        defaults.set(value, forKey: namespaced(key))
    }

    func remove(_ key: WorkspaceStateKey) {
        defaults.removeObject(forKey: namespaced(key))
    }

    func removeAll(_ keys: [WorkspaceStateKey]) {
        for key in keys { remove(key) }
    }

    private func namespaced(_ key: WorkspaceStateKey) -> String {
        prefix + key.rawValue
    }
}
