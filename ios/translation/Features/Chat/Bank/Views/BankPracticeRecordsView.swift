import SwiftUI

struct BankPracticeRecordsView: View {
    let bookName: String
    let item: BankItem

    @EnvironmentObject private var practiceRecords: PracticeRecordsStore
    @Environment(\.locale) private var locale

    private var records: [PracticeRecord] {
        practiceRecords.records
            .filter { $0.bankBookName == bookName && $0.bankItemId == item.id }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        DSScrollContainer {
            VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                if records.isEmpty {
                    EmptyStateCard(
                        title: String(localized: "practice.records.empty.title", locale: locale),
                        subtitle: String(localized: "practice.records.empty.subtitle", locale: locale),
                        iconSystemName: "doc.text.magnifyingglass"
                    )
                } else {
                    DSSectionHeader(
                        titleKey: "practice.records.list.title",
                        subtitleKey: "practice.records.list.subtitle",
                        accentUnderline: true
                    )

                    LazyVStack(spacing: DS.Spacing.md) {
                        ForEach(records) { record in
                            PracticeRecordCard(record: record)
                        }
                    }
                }
            }
        }
        .navigationTitle(String(localized: "practice.records.title", locale: locale))
        .navigationBarTitleDisplayMode(.inline)
        .background(DS.Palette.background)
    }
}
