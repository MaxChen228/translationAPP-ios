import Foundation
import Combine

enum PracticeRecordsDateFilter: Equatable {
    case all
    case today
    case last7Days
    case thisMonth
    case custom(DateInterval)

    static var presets: [PracticeRecordsDateFilter] {
        [.all, .today, .last7Days, .thisMonth]
    }

    func interval(calendar: Calendar) -> DateInterval? {
        switch self {
        case .all:
            return nil
        case .today:
            let start = calendar.startOfDay(for: Date())
            guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
                return nil
            }
            return DateInterval(start: start, end: end)
        case .last7Days:
            let today = calendar.startOfDay(for: Date())
            guard let end = calendar.date(byAdding: .day, value: 1, to: today),
                  let start = calendar.date(byAdding: .day, value: -6, to: today) else {
                return nil
            }
            return DateInterval(start: start, end: end)
        case .thisMonth:
            let now = Date()
            guard let monthInterval = calendar.dateInterval(of: .month, for: now) else {
                return nil
            }
            return monthInterval
        case .custom(let interval):
            return interval
        }
    }

    func title(locale: Locale, calendar: Calendar) -> String {
        switch self {
        case .all:
            return String(localized: "practice.records.filter.all", locale: locale)
        case .today:
            return String(localized: "practice.records.filter.today", locale: locale)
        case .last7Days:
            return String(localized: "practice.records.filter.last7", locale: locale)
        case .thisMonth:
            return String(localized: "practice.records.filter.thisMonth", locale: locale)
        case .custom(let interval):
            let formatter = DateFormatter()
            formatter.locale = locale
            formatter.dateStyle = .medium
            let start = formatter.string(from: interval.start)
            let endReference = calendar.date(byAdding: .second, value: -1, to: interval.end) ?? interval.end
            let end = formatter.string(from: endReference)
            let format = String(localized: "practice.records.filter.custom", defaultValue: "%@ – %@", locale: locale)
            return String(format: format, start, end)
        }
    }
}

@MainActor
final class PracticeRecordsListViewModel: ObservableObject {
    @Published var filter: PracticeRecordsDateFilter = .all {
        didSet {
            guard oldValue != filter else { return }
            applyFilter()
        }
    }
    @Published private(set) var displayedRecords: [PracticeRecord] = []
    @Published private(set) var stats: (totalRecords: Int, averageScore: Double, totalErrors: Int) = (0, 0.0, 0)
    @Published private(set) var hasMore: Bool = false
    @Published private(set) var isLoadingMore: Bool = false
    @Published var isShowingCustomDateSheet: Bool = false

    var totalRecordsOverall: Int {
        store.records.count
    }

    var selectedCustomRange: DateInterval? {
        if case .custom(let interval) = filter {
            return interval
        }
        return nil
    }

    private var cancellables = Set<AnyCancellable>()
    private let store: PracticeRecordsStore
    private let calendar: Calendar
    private let initialBatchSize = 20
    private let subsequentBatchSize = 10
    private var currentOffset: Int = 0
    private var currentRange: DateInterval? = nil

    init(store: PracticeRecordsStore, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
        bindStore()
    }

    func loadMoreIfNeeded(currentItem item: PracticeRecord?) {
        guard let item else { return }
        guard hasMore, !isLoadingMore else { return }
        guard displayedRecords.last == item else { return }
        loadNextPage()
    }

    func applyCustomRange(start: Date, end: Date) {
        guard let interval = makeInterval(start: start, end: end) else { return }
        filter = .custom(interval)
        isShowingCustomDateSheet = false
    }

    func resetFilter() {
        filter = .all
    }

    private func bindStore() {
        store.$records
            .sink { [weak self] _ in
                self?.applyFilter(resetOffset: true)
            }
            .store(in: &cancellables)
    }

    private func applyFilter(resetOffset: Bool = true) {
        if resetOffset {
            currentOffset = 0
            displayedRecords.removeAll()
        }
        currentRange = filter.interval(calendar: calendar)
        stats = store.statistics(range: currentRange)
        hasMore = stats.totalRecords > 0
        isLoadingMore = false
        if stats.totalRecords == 0 {
            displayedRecords = []
            hasMore = false
            return
        }
        loadNextPage(initial: true)
    }

    private func loadNextPage(initial: Bool = false) {
        guard !isLoadingMore else { return }
        isLoadingMore = true
        let nextLimit = initial ? initialBatchSize : subsequentBatchSize
        let records = store.query(range: currentRange, offset: currentOffset, limit: nextLimit)
        currentOffset += records.count
        if initial {
            displayedRecords = records
        } else {
            displayedRecords.append(contentsOf: records)
        }
        hasMore = currentOffset < stats.totalRecords
        isLoadingMore = false
    }

    func delete(_ record: PracticeRecord) {
        store.remove(record.id)
    }

    func clearAll() {
        store.clearAll()
    }

    private func makeInterval(start: Date, end: Date) -> DateInterval? {
        let normalizedStart = calendar.startOfDay(for: start)
        let normalizedEndStart = calendar.startOfDay(for: end)
        guard let exclusiveEnd = calendar.date(byAdding: .day, value: 1, to: normalizedEndStart), exclusiveEnd > normalizedStart else {
            return nil
        }
        return DateInterval(start: normalizedStart, end: exclusiveEnd)
    }
}
