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
        self.init(repository: PracticeRecordsFileSystem.makeRepository())
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

    func query(range: DateInterval?, offset: Int, limit: Int) -> [PracticeRecord] {
        guard limit > 0 else { return [] }

        let filtered = filteredRecords(range: range)
        guard !filtered.isEmpty else { return [] }

        let clampedOffset = max(0, min(offset, filtered.count))
        let end = min(filtered.count, clampedOffset + limit)
        guard clampedOffset < end else { return [] }

        return Array(filtered[clampedOffset..<end])
    }

    func statistics(range: DateInterval?) -> (totalRecords: Int, averageScore: Double, totalErrors: Int) {
        let filtered = filteredRecords(range: range)
        guard !filtered.isEmpty else {
            return (0, 0.0, 0)
        }

        let total = filtered.count
        let scoreSum = filtered.reduce(0) { $0 + $1.score }
        let totalErrors = filtered.reduce(0) { $0 + $1.errors.count }
        let avgScore = Double(scoreSum) / Double(total)
        return (total, avgScore, totalErrors)
    }

    private func persist() {
        do {
            try repository.saveRecords(records)
        } catch {
            AppLog.aiError("Failed to persist practice records: \(error)")
        }
    }

    private func filteredRecords(range: DateInterval?) -> [PracticeRecord] {
        let sorted = records.sorted { $0.createdAt > $1.createdAt }
        guard let range else { return sorted }

        return sorted.filter { record in
            range.contains(record.createdAt)
        }
    }
}
