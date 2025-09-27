import Foundation

@MainActor
final class PracticeSessionCoordinator: ObservableObject {
    enum PracticeSource: Equatable {
        case local(bookName: String)
    }

    enum PracticeError: LocalizedError {
        case notLocal
        case storeMissing
        case noneRemaining
        case missingResponse

        var errorDescription: String? {
            switch self {
            case .notLocal:
                return String(localized: "practice.error.notLocal")
            case .storeMissing:
                return String(localized: "practice.error.storeMissing")
            case .noneRemaining:
                return String(localized: "practice.error.noneRemaining")
            case .missingResponse:
                return nil
            }
        }
    }

    @Published private(set) var practiceSource: PracticeSource? = nil
    @Published private(set) var currentBankItemId: String? = nil
    @Published private(set) var currentPracticeTag: String? = nil

    private let session: CorrectionSessionStore
    private weak var localBankStore: LocalBankStore?
    private weak var localProgressStore: LocalBankProgressStore?
    private weak var practiceRecordsStore: PracticeRecordsStore?
    private weak var randomPracticeStore: RandomPracticeStore?
    private var practiceStartTime: Date? = nil

    init(session: CorrectionSessionStore) {
        self.session = session
    }

    func setLocalStores(localBank: LocalBankStore?, progress: LocalBankProgressStore?) {
        self.localBankStore = localBank
        self.localProgressStore = progress
    }

    func setPracticeRecordsStore(_ store: PracticeRecordsStore?) {
        self.practiceRecordsStore = store
    }

    func setRandomPracticeStore(_ store: RandomPracticeStore?) {
        self.randomPracticeStore = store
    }

    func startLocalPractice(bookName: String, item: BankItem, tag: String?) {
        practiceSource = .local(bookName: bookName)
        currentBankItemId = item.id
        currentPracticeTag = tag ?? item.tags?.first
        session.prepareForPractice(zh: item.zh, hints: item.hints, suggestion: item.suggestion)
        session.updateCurrentBankItem(id: item.id)
        session.updateCurrentPracticeTag(currentPracticeTag)
        practiceStartTime = Date()
    }

    func resetPractice() {
        practiceSource = nil
        currentBankItemId = nil
        currentPracticeTag = nil
        practiceStartTime = nil
        session.updateCurrentBankItem(id: nil)
        session.updateCurrentPracticeTag(nil)
        session.updateSuggestion(nil)
    }

    func loadNextPractice() throws {
        if let randomPick = pickRandomPracticeItem() {
            let (bookName, item) = randomPick
            startLocalPractice(bookName: bookName, item: item, tag: item.tags?.first)
            return
        }

        try loadSequentialFallback()
    }

    func savePracticeRecord(currentInput: String, response: AIResponse?) throws -> PracticeRecord {
        guard let response else {
            throw PracticeError.missingResponse
        }
        guard let store = practiceRecordsStore else {
            throw PracticeError.storeMissing
        }

        let createdAt = practiceStartTime ?? Date()
        let completedAt = Date()
        let bankBookName: String?
        if case .local(let name) = practiceSource {
            bankBookName = name
        } else {
            bankBookName = nil
        }

        let record = PracticeRecord(
            createdAt: createdAt,
            completedAt: completedAt,
            bankItemId: currentBankItemId,
            bankBookName: bankBookName,
            practiceTag: currentPracticeTag,
            chineseText: session.inputZh,
            englishInput: currentInput,
            hints: session.practicedHints,
            teacherSuggestion: session.currentSuggestion,
            correctedText: response.corrected,
            score: response.score,
            errors: response.errors
        )

        store.add(record)
        if case .local(let name) = practiceSource,
           let progress = localProgressStore,
           let itemId = currentBankItemId,
           !progress.isCompleted(book: name, itemId: itemId) {
            progress.markCompleted(book: name, itemId: itemId, score: response.score)
        }

        return record
    }
}

private extension PracticeSessionCoordinator {
    func loadSequentialFallback() throws {
        guard case .local(let bookName) = practiceSource else {
            throw PracticeError.notLocal
        }
        guard let bank = localBankStore, let progress = localProgressStore else {
            throw PracticeError.storeMissing
        }

        let items = bank.items(in: bookName)
        let next = items.first(where: { item in
            item.id != currentBankItemId && !progress.isCompleted(book: bookName, itemId: item.id)
        }) ?? items.first(where: { !progress.isCompleted(book: bookName, itemId: $0.id) })

        guard let candidate = next else {
            throw PracticeError.noneRemaining
        }

        startLocalPractice(bookName: bookName, item: candidate, tag: candidate.tags?.first)
    }

    func pickRandomPracticeItem() -> (String, BankItem)? {
        guard let randomPracticeStore,
              let bank = localBankStore,
              let progress = localProgressStore else {
            return nil
        }

        let availableNames = Set(bank.books.map { $0.name })
        let normalizedScope = randomPracticeStore.normalizedBookScope(with: availableNames)
        let allowedNames = normalizedScope.isEmpty ? availableNames : normalizedScope
        guard !allowedNames.isEmpty else { return nil }

        var pool: [(String, BankItem)] = []

        for book in bank.books where allowedNames.contains(book.name) {
            for item in book.items {
                if randomPracticeStore.excludeCompleted,
                   progress.isCompleted(book: book.name, itemId: item.id) {
                    continue
                }

                if !randomPracticeStore.selectedDifficulties.isEmpty,
                   !randomPracticeStore.selectedDifficulties.contains(item.difficulty) {
                    continue
                }

                if randomPracticeStore.filterState.hasActiveFilters {
                    guard let tags = item.tags, !tags.isEmpty else { continue }
                    guard randomPracticeStore.filterState.matches(tags: tags) else { continue }
                }

                pool.append((book.name, item))
            }
        }

        return pool.randomElement()
    }
}
