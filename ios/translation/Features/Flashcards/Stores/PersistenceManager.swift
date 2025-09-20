import Foundation

protocol PersistenceManager {
    func save<T: Codable>(_ data: T, forKey key: String) throws
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T?
}

final class UserDefaultsPersistenceManager: PersistenceManager {
    func save<T: Codable>(_ data: T, forKey key: String) throws {
        let encoded = try JSONEncoder().encode(data)
        UserDefaults.standard.set(encoded, forKey: key)
    }

    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }
}