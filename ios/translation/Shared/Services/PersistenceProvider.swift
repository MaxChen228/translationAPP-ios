import Foundation

enum PersistenceError: Error {
    case fileNotFound
    case failedToRead(underlying: Error)
    case failedToWrite(underlying: Error)
    case failedToDelete(underlying: Error)
    case decodeError(underlying: Error)
    case encodeError(underlying: Error)
}

protocol PersistenceProvider {
    func loadData(for key: String) throws -> Data
    func saveData(_ data: Data, for key: String) throws
    func deleteData(for key: String) throws
    func listKeys() throws -> [String]
}

final class FilePersistenceProvider: PersistenceProvider {
    private let directoryURL: URL
    private let fileManager: FileManager

    init(directory: URL, fileManager: FileManager = .default) throws {
        self.directoryURL = directory
        self.fileManager = fileManager
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func loadData(for key: String) throws -> Data {
        let url = directoryURL.appendingPathComponent(key)
        guard fileManager.fileExists(atPath: url.path) else {
            throw PersistenceError.fileNotFound
        }
        do {
            return try Data(contentsOf: url)
        } catch {
            throw PersistenceError.failedToRead(underlying: error)
        }
    }

    func saveData(_ data: Data, for key: String) throws {
        let url = directoryURL.appendingPathComponent(key)
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            throw PersistenceError.failedToWrite(underlying: error)
        }
    }

    func deleteData(for key: String) throws {
        let url = directoryURL.appendingPathComponent(key)
        guard fileManager.fileExists(atPath: url.path) else { return }
        do {
            try fileManager.removeItem(at: url)
        } catch {
            throw PersistenceError.failedToDelete(underlying: error)
        }
    }

    func listKeys() throws -> [String] {
        do {
            return try fileManager.contentsOfDirectory(atPath: directoryURL.path)
        } catch {
            throw PersistenceError.failedToRead(underlying: error)
        }
    }
}

final class MemoryPersistenceProvider: PersistenceProvider {
    private var storage: [String: Data] = [:]

    func loadData(for key: String) throws -> Data {
        guard let data = storage[key] else { throw PersistenceError.fileNotFound }
        return data
    }

    func saveData(_ data: Data, for key: String) throws {
        storage[key] = data
    }

    func deleteData(for key: String) throws {
        storage.removeValue(forKey: key)
    }

    func listKeys() throws -> [String] {
        Array(storage.keys)
    }
}
