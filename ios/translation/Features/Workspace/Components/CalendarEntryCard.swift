import SwiftUI

struct CalendarEntryCard: View {
    @EnvironmentObject private var practiceRecords: PracticeRecordsStore
    @Environment(\.locale) private var locale

    private var todayCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        return practiceRecords.records.filter { record in
            record.createdAt >= today && record.createdAt < tomorrow
        }.count
    }

    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSCardTitle(
                    icon: "calendar",
                    title: "quick.calendar.title",
                    accentColor: DS.Brand.scheme.provence
                )
                DSSeparator(color: DS.Palette.border.opacity(0.12))
                Text(subtitleText)
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: DS.CardSize.minHeightStandard)
        }
    }

    private var subtitleText: LocalizedStringKey {
        if todayCount > 0 {
            return "quick.calendar.subtitle.active"
        } else {
            return "quick.calendar.subtitle.empty"
        }
    }
}