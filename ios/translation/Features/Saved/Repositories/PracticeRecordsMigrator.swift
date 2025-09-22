import Foundation

struct PracticeRecordsMigrator {
    private let oldDefaultsKey = "practice.records"
    private let defaults: UserDefaults
    private let fileManager: FileManager
    private let backupDirectory: URL

    init(
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        backupDirectory: URL
    ) {
        self.defaults = defaults
        self.fileManager = fileManager
        self.backupDirectory = backupDirectory
    }

    func migrateIfNeeded(repository: PracticeRecordsRepositoryProtocol) {
        guard let data = defaults.data(forKey: oldDefaultsKey), !data.isEmpty else { return }

        do {
            try createBackupDirectoryIfNeeded()
            let backupURL = backupDirectory.appendingPathComponent("practice_records_backup_\(timestamp()).json")
            try data.write(to: backupURL, options: .atomic)

            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let legacyRecords = try decoder.decode([PracticeRecord].self, from: data)

            let existing = (try? repository.loadRecords()) ?? []
            let merged = merge(existing: existing, legacy: legacyRecords)
            try repository.saveRecords(merged)
            defaults.removeObject(forKey: oldDefaultsKey)
            AppLog.aiInfo("Practice records migration completed: legacy=\(legacyRecords.count), total=\(merged.count)")
        } catch {
            AppLog.aiError("Practice records migration failed: \(error)")
        }
    }

    private func merge(existing: [PracticeRecord], legacy: [PracticeRecord]) -> [PracticeRecord] {
        var table: [UUID: PracticeRecord] = existing.reduce(into: [:]) { $0[$1.id] = $1 }
        for record in legacy {
            table[record.id] = record
        }
        return table.values.sorted { $0.createdAt < $1.createdAt }
    }

    private func createBackupDirectoryIfNeeded() throws {
        try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
    }

    private func timestamp() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: Date())
    }
}
