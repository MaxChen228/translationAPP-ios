import Foundation
import SwiftUI

@MainActor
final class PracticeRecordsStore: ObservableObject {
    @Published private(set) var records: [PracticeRecord] = []

    private let repository: PracticeRecordsRepositoryProtocol

    init(repository: PracticeRecordsRepositoryProtocol) {
        self.repository = repository
        self.records = (try? repository.loadRecords()) ?? []
    }

    convenience init() {
        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("practiceRecords-temp-\(UUID().uuidString)", isDirectory: true)
        let provider: PersistenceProvider
        if let fileProvider = try? FilePersistenceProvider(directory: tempDirectory) {
            provider = fileProvider
        } else {
            provider = MemoryPersistenceProvider()
        }
        let repository = PracticeRecordsRepository(provider: provider)
        self.init(repository: repository)
    }

    func reload() {
        records = (try? repository.loadRecords()) ?? []
    }

    func add(_ record: PracticeRecord) {
        records.append(record)
        persist()
    }

    func remove(_ id: UUID) {
        records.removeAll { $0.id == id }
        persist()
    }

    func clearAll() {
        records = []
        persist()
    }

    func getRecord(by id: UUID) -> PracticeRecord? {
        records.first { $0.id == id }
    }

    func getRecords(for bankBookName: String) -> [PracticeRecord] {
        records.filter { $0.bankBookName == bankBookName }
    }

    func getRecords(with score: Int) -> [PracticeRecord] {
        records.filter { $0.score == score }
    }

    func getRecordsGroupedByDate() -> [String: [PracticeRecord]] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        return Dictionary(grouping: records) { record in
            formatter.string(from: record.createdAt)
        }
    }

    func getStatistics() -> (totalRecords: Int, averageScore: Double, totalErrors: Int) {
        let total = records.count
        let avgScore = records.isEmpty ? 0.0 : Double(records.map { $0.score }.reduce(0, +)) / Double(total)
        let totalErrors = records.map { $0.errors.count }.reduce(0, +)
        return (total, avgScore, totalErrors)
    }

    private func persist() {
        do {
            try repository.saveRecords(records)
        } catch {
            AppLog.aiError("Failed to persist practice records: \(error)")
        }
    }
}
