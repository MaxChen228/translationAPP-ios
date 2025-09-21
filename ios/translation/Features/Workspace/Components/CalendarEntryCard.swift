import SwiftUI

struct CalendarEntryCard: View {
    @EnvironmentObject private var practiceRecords: PracticeRecordsStore

    private var todayCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        return practiceRecords.records.filter { record in
            record.createdAt >= today && record.createdAt < tomorrow
        }.count
    }

    private var weekCount: Int {
        guard let weekStart = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start else { return 0 }
        let weekEnd = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: weekStart)!

        return practiceRecords.records.filter { record in
            record.createdAt >= weekStart && record.createdAt < weekEnd
        }.count
    }

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    Image(systemName: "calendar")
                        .font(.title2)
                        .foregroundStyle(DS.Palette.primary)

                    Spacer()

                    if todayCount > 0 {
                        Text("\(todayCount)")
                            .font(DS.Font.labelMd)
                            .fontWeight(.semibold)
                            .foregroundStyle(DS.Palette.onPrimary)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(
                                Circle()
                                    .fill(DS.Palette.primary)
                            )
                    }
                }

                Text("練習日曆")
                    .font(DS.Font.section)
                    .fontWeight(.semibold)

                if todayCount > 0 || weekCount > 0 {
                    VStack(alignment: .leading, spacing: 4) {
                        if todayCount > 0 {
                            HStack {
                                Circle()
                                    .fill(DS.Palette.success)
                                    .frame(width: 6, height: 6)
                                Text("今日已練習 \(todayCount) 題")
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Palette.subdued)
                            }
                        }

                        if weekCount > 0 {
                            HStack {
                                Circle()
                                    .fill(DS.Palette.primary.opacity(0.6))
                                    .frame(width: 6, height: 6)
                                Text("本週共 \(weekCount) 題")
                                    .font(DS.Font.caption)
                                    .foregroundStyle(DS.Palette.subdued)
                            }
                        }
                    }
                } else {
                    Text("檢視練習歷程")
                        .font(DS.Font.caption)
                        .foregroundStyle(DS.Palette.subdued)
                }
            }
        }
    }
}