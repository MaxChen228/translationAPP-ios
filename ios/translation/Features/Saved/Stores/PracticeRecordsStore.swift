import Foundation
import SwiftUI

@MainActor
final class PracticeRecordsStore: ObservableObject {
    private let defaultsKey = "practice.records"

    @Published private(set) var records: [PracticeRecord] = [] {
        didSet { persist() }
    }

    init() { load() }

    func add(_ record: PracticeRecord) {
        records.append(record)
    }

    func remove(_ id: UUID) {
        records.removeAll { $0.id == id }
    }

    func clearAll() {
        records = []
    }

    func getRecord(by id: UUID) -> PracticeRecord? {
        records.first { $0.id == id }
    }

    func getRecords(for workspaceId: String) -> [PracticeRecord] {
        records.filter { $0.workspaceId == workspaceId }
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

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            records = try decoder.decode([PracticeRecord].self, from: data)
        } catch {
            records = []
        }
    }

    private func persist() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(records)
            UserDefaults.standard.set(data, forKey: defaultsKey)
        } catch {
            // ignore persist errors
        }
    }
}