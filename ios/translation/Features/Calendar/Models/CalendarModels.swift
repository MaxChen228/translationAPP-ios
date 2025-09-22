import Foundation

struct CalendarDay: Equatable {
    let date: Date
    let isCurrentMonth: Bool
    let isToday: Bool
    let practiceCount: Int
    let averageScore: Double?
    let errorCount: Int

    var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var hasActivity: Bool {
        practiceCount > 0
    }
}

struct CalendarMonth {
    let year: Int
    let month: Int
    let days: [CalendarDay]

    var monthYear: String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = .autoupdatingCurrent
        formatter.setLocalizedDateFormatFromTemplate("yyyyMMMM")
        let date = Calendar.current.date(from: DateComponents(year: year, month: month)) ?? Date()
        return formatter.string(from: date)
    }
}

struct DayPracticeStats {
    let date: Date
    let records: [PracticeRecord]
    let streakDays: Int

    var count: Int { records.count }
    var averageScore: Double {
        guard !records.isEmpty else { return 0 }
        return Double(records.map(\.score).reduce(0, +)) / Double(records.count)
    }
    var totalErrors: Int {
        records.map(\.errors.count).reduce(0, +)
    }
    var bestScore: Int {
        records.map(\.score).max() ?? 0
    }
    var practiceTime: TimeInterval {
        records.map { $0.completedAt.timeIntervalSince($0.createdAt) }.reduce(0, +)
    }
}
