import Foundation

enum CorrectionPracticeSource: Equatable {
    case local(bookName: String)
}

enum CorrectionPracticeSessionError: LocalizedError, Equatable {
    case notLocal
    case missingLocalStores
    case missingPracticeStore
    case noRemainingItems

    var errorDescription: String? {
        switch self {
        case .notLocal:
            return String(localized: "practice.error.notLocal")
        case .missingLocalStores:
            return String(localized: "practice.error.storeMissing")
        case .missingPracticeStore:
            return String(localized: "practice.error.practiceStoreMissing", defaultValue: "Practice records store not configured")
        case .noRemainingItems:
            return String(localized: "practice.error.noneRemaining")
        }
    }
}

struct CorrectionPracticeState {
    var inputZh: String
    var inputEn: String
    var practicedHints: [BankHint]
    var showPracticedHints: Bool
    var response: AIResponse?
    var practiceSource: CorrectionPracticeSource?
    var currentBankItemId: String?
    var currentPracticeTag: String?
    var suggestion: String?
}

protocol CorrectionPracticeSession {
    var practiceSource: CorrectionPracticeSource? { get }
    var currentBankItemId: String? { get }
    var currentPracticeTag: String? { get }
    var currentSuggestion: String? { get }

    func bindLocalStores(localBank: LocalBankStore, progress: LocalBankProgressStore)
    func bindPracticeRecordsStore(_ store: PracticeRecordsStore)
    func startLocalPractice(bookName: String, item: BankItem, tag: String?) -> CorrectionPracticeState
    func loadNextPractice() async throws -> CorrectionPracticeState
    func savePracticeRecord(response: AIResponse, inputZh: String, inputEn: String, hints: [BankHint]) throws -> PracticeRecord
    func resetContext()
}

final class DefaultCorrectionPracticeSession: CorrectionPracticeSession {
    private(set) var practiceSource: CorrectionPracticeSource? = nil
    private(set) var currentBankItemId: String? = nil
    private(set) var currentPracticeTag: String? = nil
    private(set) var currentSuggestion: String? = nil

    private weak var localBankStore: LocalBankStore?
    private weak var localProgressStore: LocalBankProgressStore?
    private weak var practiceRecordsStore: PracticeRecordsStore?

    private var practiceStartTime: Date? = nil

    func bindLocalStores(localBank: LocalBankStore, progress: LocalBankProgressStore) {
        self.localBankStore = localBank
        self.localProgressStore = progress
    }

    func bindPracticeRecordsStore(_ store: PracticeRecordsStore) {
        self.practiceRecordsStore = store
    }

    func startLocalPractice(bookName: String, item: BankItem, tag: String?) -> CorrectionPracticeState {
        updatePracticeContext(source: .local(bookName: bookName), item: item, tag: tag ?? item.tags?.first)
        return buildState(from: item)
    }

    func loadNextPractice() async throws -> CorrectionPracticeState {
        guard case .local(let bookName) = practiceSource else {
            throw CorrectionPracticeSessionError.notLocal
        }
        guard let bank = localBankStore, let progress = localProgressStore else {
            throw CorrectionPracticeSessionError.missingLocalStores
        }

        let items = bank.items(in: bookName)
        guard !items.isEmpty else {
            throw CorrectionPracticeSessionError.noRemainingItems
        }

        if let next = items.first(where: { !progress.isCompleted(book: bookName, itemId: $0.id) && $0.id != currentBankItemId })
            ?? items.first(where: { !progress.isCompleted(book: bookName, itemId: $0.id) }) {
            updatePracticeContext(source: .local(bookName: bookName), item: next, tag: next.tags?.first)
            return buildState(from: next)
        }

        throw CorrectionPracticeSessionError.noRemainingItems
    }

    func savePracticeRecord(response: AIResponse, inputZh: String, inputEn: String, hints: [BankHint]) throws -> PracticeRecord {
        guard let store = practiceRecordsStore else {
            throw CorrectionPracticeSessionError.missingPracticeStore
        }

        let startTime = practiceStartTime ?? Date()
        let bankBookName: String? = {
            if case .local(let bookName) = practiceSource { return bookName }
            return nil
        }()

        let record = PracticeRecord(
            createdAt: startTime,
            completedAt: Date(),
            bankItemId: currentBankItemId,
            bankBookName: bankBookName,
            practiceTag: currentPracticeTag,
            chineseText: inputZh,
            englishInput: inputEn,
            hints: hints,
            teacherSuggestion: currentSuggestion,
            correctedText: response.corrected,
            score: response.score,
            errors: response.errors
        )

        store.add(record)
        AppLog.aiInfo("Practice record saved successfully: score=\(response.score), errors=\(response.errors.count), total records=\(store.records.count)")

        if case .local(let bookName) = practiceSource, let itemId = currentBankItemId, let progress = localProgressStore {
            if !progress.isCompleted(book: bookName, itemId: itemId) {
                progress.markCompleted(book: bookName, itemId: itemId, score: response.score)
            }
        }

        practiceStartTime = nil
        return record
    }

    func resetContext() {
        practiceSource = nil
        currentBankItemId = nil
        currentPracticeTag = nil
        currentSuggestion = nil
        practiceStartTime = nil
    }

    private func updatePracticeContext(source: CorrectionPracticeSource, item: BankItem, tag: String?) {
        practiceSource = source
        currentBankItemId = item.id
        currentPracticeTag = tag
        currentSuggestion = item.suggestion
        practiceStartTime = Date()
    }

    private func buildState(from item: BankItem) -> CorrectionPracticeState {
        CorrectionPracticeState(
            inputZh: item.zh,
            inputEn: "",
            practicedHints: item.hints,
            showPracticedHints: false,
            response: nil,
            practiceSource: practiceSource,
            currentBankItemId: currentBankItemId,
            currentPracticeTag: currentPracticeTag,
            suggestion: currentSuggestion
        )
    }
}
