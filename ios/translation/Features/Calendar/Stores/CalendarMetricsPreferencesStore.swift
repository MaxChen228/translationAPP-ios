import Foundation
import SwiftUI

enum CalendarMetric: String, CaseIterable, Identifiable, Codable, Hashable {
    case practiceCount
    case totalErrors
    case bestScore
    case averageScore
    case practiceTime
    case streakDays

    static let maxVisibleCount = 4
    static let defaultVisible: [CalendarMetric] = [.practiceCount, .totalErrors, .bestScore]

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .practiceCount: return "練習題數"
        case .totalErrors: return "錯誤總數"
        case .bestScore: return "最高分"
        case .averageScore: return "平均分"
        case .practiceTime: return "練習時間"
        case .streakDays: return "連續天數"
        }
    }

    var systemImage: String {
        switch self {
        case .practiceCount: return "doc.text.magnifyingglass"
        case .totalErrors: return "exclamationmark.triangle"
        case .bestScore: return "rosette"
        case .averageScore: return "chart.bar"
        case .practiceTime: return "clock"
        case .streakDays: return "flame"
        }
    }

    func value(for stats: DayPracticeStats, locale: Locale, calendar: Calendar) -> String {
        switch self {
        case .practiceCount:
            return NumberFormatter.calendarMetricInteger.string(from: NSNumber(value: stats.count)) ?? "\(stats.count)"
        case .totalErrors:
            return NumberFormatter.calendarMetricInteger.string(from: NSNumber(value: stats.totalErrors)) ?? "\(stats.totalErrors)"
        case .bestScore:
            return NumberFormatter.calendarMetricInteger.string(from: NSNumber(value: stats.bestScore)) ?? "\(stats.bestScore)"
        case .averageScore:
            let average = stats.count > 0 ? stats.averageScore : 0
            return NumberFormatter.calendarMetricDecimal.string(from: NSNumber(value: average)) ?? String(format: "%.1f", average)
        case .practiceTime:
            return CalendarFormatting.practiceDuration(stats.practiceTime, locale: locale) ?? "—"
        case .streakDays:
            return NumberFormatter.calendarMetricInteger.string(from: NSNumber(value: stats.streakDays)) ?? "\(stats.streakDays)"
        }
    }
}

@MainActor
final class CalendarMetricsPreferencesStore: ObservableObject {
    @Published private(set) var visibleMetrics: [CalendarMetric]

    private let defaults: UserDefaults
    private let storageKey = "calendar.visibleMetrics"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.array(forKey: storageKey) as? [String] {
            let metrics = raw.compactMap(CalendarMetric.init(rawValue:))
            self.visibleMetrics = metrics.isEmpty ? CalendarMetric.defaultVisible : Array(metrics.prefix(CalendarMetric.maxVisibleCount))
        } else {
            self.visibleMetrics = CalendarMetric.defaultVisible
        }
    }

    func isVisible(_ metric: CalendarMetric) -> Bool {
        visibleMetrics.contains(metric)
    }

    func toggleVisibility(for metric: CalendarMetric) {
        if isVisible(metric) {
            remove(metric)
        } else {
            append(metric)
        }
    }

    func append(_ metric: CalendarMetric) {
        guard !isVisible(metric), visibleMetrics.count < CalendarMetric.maxVisibleCount else { return }
        visibleMetrics.append(metric)
        persist()
    }

    func remove(_ metric: CalendarMetric) {
        guard let index = visibleMetrics.firstIndex(of: metric), visibleMetrics.count > 1 else { return }
        visibleMetrics.remove(at: index)
        persist()
    }

    func move(metric: CalendarMetric, to index: Int) {
        guard let currentIndex = visibleMetrics.firstIndex(of: metric), currentIndex != index,
              index >= 0, index <= visibleMetrics.count else { return }
        let item = visibleMetrics.remove(at: currentIndex)
        visibleMetrics.insert(item, at: index)
        persist()
    }

    func move(metric: CalendarMetric, before target: CalendarMetric) {
        guard let targetIndex = visibleMetrics.firstIndex(of: target) else { return }
        guard let currentIndex = visibleMetrics.firstIndex(of: metric), currentIndex != targetIndex else { return }
        var destination = targetIndex
        if currentIndex < targetIndex {
            destination = max(0, destination - 1)
        }
        move(metric: metric, to: destination)
    }

    func moveToEnd(_ metric: CalendarMetric) {
        guard let currentIndex = visibleMetrics.firstIndex(of: metric) else { return }
        let item = visibleMetrics.remove(at: currentIndex)
        visibleMetrics.append(item)
        persist()
    }

    func reset() {
        visibleMetrics = CalendarMetric.defaultVisible
        persist()
    }

    private func persist() {
        defaults.set(visibleMetrics.map(\.rawValue), forKey: storageKey)
    }
}

private extension NumberFormatter {
    static let calendarMetricInteger: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let calendarMetricDecimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()
}
