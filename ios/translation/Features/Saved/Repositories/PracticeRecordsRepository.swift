import Foundation

struct PracticeRecordsDTO: Codable {
    var records: [PracticeRecord]
}

protocol PracticeRecordsRepositoryProtocol {
    func loadRecords() throws -> [PracticeRecord]
    func saveRecords(_ records: [PracticeRecord]) throws
}

final class PracticeRecordsRepository: PracticeRecordsRepositoryProtocol {
    private let provider: PersistenceProvider
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let storageKey = "records.json"

    init(provider: PersistenceProvider) {
        self.provider = provider
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    func loadRecords() throws -> [PracticeRecord] {
        do {
            let data = try provider.loadData(for: storageKey)
            let dto = try decoder.decode(PracticeRecordsDTO.self, from: data)
            return dto.records
        } catch PersistenceError.fileNotFound {
            return []
        } catch let error as DecodingError {
            throw PersistenceError.decodeError(underlying: error)
        } catch {
            throw error
        }
    }

    func saveRecords(_ records: [PracticeRecord]) throws {
        do {
            let dto = PracticeRecordsDTO(records: records)
            let data = try encoder.encode(dto)
            try provider.saveData(data, for: storageKey)
        } catch let error as EncodingError {
            throw PersistenceError.encodeError(underlying: error)
        } catch {
            throw error
        }
    }
}

enum PracticeRecordsFileSystem {
    private static let recordsFolderName = "PracticeRecords"
    private static let backupFolderName = "Backups"
    private static let appFolderName = "translation"

    static func baseDirectory(fileManager: FileManager = .default) -> URL {
        if let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return base.appendingPathComponent(appFolderName, isDirectory: true)
        }
        return fileManager.temporaryDirectory.appendingPathComponent(appFolderName, isDirectory: true)
    }

    static func recordsDirectory(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent(recordsFolderName, isDirectory: true)
    }

    static func backupDirectory(fileManager: FileManager = .default) -> URL {
        baseDirectory(fileManager: fileManager).appendingPathComponent(backupFolderName, isDirectory: true)
    }

    static func makeRepository(fileManager: FileManager = .default) -> PracticeRecordsRepository {
        let provider = makeProvider(fileManager: fileManager)
        return PracticeRecordsRepository(provider: provider)
    }

    static func makeProvider(fileManager: FileManager = .default) -> PersistenceProvider {
        do {
            return try FilePersistenceProvider(directory: recordsDirectory(fileManager: fileManager), fileManager: fileManager)
        } catch {
            AppLog.aiError("Failed to initialize file persistence for practice records: \(error)")
            return MemoryPersistenceProvider()
        }
    }
}
