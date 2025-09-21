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
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.title3)
                        .foregroundStyle(DS.Brand.scheme.provence.opacity(0.85))
                        .frame(width: 28)
                    Text("quick.calendar.title")
                        .dsType(DS.Font.serifBody)
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                DSSeparator(color: DS.Palette.border.opacity(0.12))
                Text(subtitleText)
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(minHeight: 104)
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