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


extension CalendarMonth {
    func formattedMonthYear(locale: Locale, calendar: Calendar) -> String {
        CalendarFormatting.monthYear(year: year, month: month, locale: locale, calendar: calendar)
    }
}

enum CalendarFormatting {
    static func monthYear(year: Int, month: Int, locale: Locale, calendar: Calendar) -> String {
        var components = DateComponents()
        components.calendar = calendar
        components.year = year
        components.month = month
        components.day = 1

        guard let date = components.date else { return "" }

        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.setLocalizedDateFormatFromTemplate("yMMMM")
        return formatter.string(from: date)
    }

    static func monthAndDay(_ date: Date, locale: Locale, calendar: Calendar) -> (month: String, day: String) {
        let monthFormatter = DateFormatter()
        monthFormatter.calendar = calendar
        monthFormatter.locale = locale
        monthFormatter.setLocalizedDateFormatFromTemplate("MMMM")

        let dayFormatter = DateFormatter()
        dayFormatter.calendar = calendar
        dayFormatter.locale = locale
        dayFormatter.setLocalizedDateFormatFromTemplate("d")

        let month = monthFormatter.string(from: date)
        let day = dayFormatter.string(from: date)
        return (month, day)
    }

    static func practiceDuration(_ interval: TimeInterval, locale: Locale) -> String? {
        guard interval > 0 else { return nil }

        let duration = Duration.seconds(interval)
        let style = Duration.UnitsFormatStyle.units(
            allowed: [.hours, .minutes],
            width: .wide,
            maximumUnitCount: 2
        ).locale(locale)

        let formatted = duration.formatted(style)
        return formatted.isEmpty ? nil : formatted
    }
}
