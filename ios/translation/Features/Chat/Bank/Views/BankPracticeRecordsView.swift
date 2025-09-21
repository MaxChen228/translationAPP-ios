import SwiftUI

private func difficultyToRoman(_ difficulty: Int) -> String {
    switch difficulty {
    case 1: return "Ⅰ"
    case 2: return "Ⅱ"
    case 3: return "Ⅲ"
    case 4: return "Ⅳ"
    case 5: return "Ⅴ"
    default: return "Ⅰ"
    }
}

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

    private var stats: (attempts: Int, averageScore: Double, bestScore: Int?) {
        guard !records.isEmpty else { return (0, 0, nil) }
        let total = records.reduce(into: 0) { $0 += $1.score }
        let best = records.map(\.score).max()
        return (records.count, Double(total) / Double(records.count), best)
    }

    var body: some View {
        DSScrollContainer {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                overviewCard

                if records.isEmpty {
                    EmptyStateCard(
                        title: String(localized: "practice.records.empty.title", locale: locale),
                        subtitle: String(localized: "practice.records.empty.subtitle", locale: locale),
                        iconSystemName: "doc.text.magnifyingglass"
                    )
                } else {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
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
        }
        .navigationTitle(String(localized: "practice.records.title", locale: locale))
        .navigationBarTitleDisplayMode(.inline)
        .background(DS.Palette.background)
    }

    private var overviewCard: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
                    Text(bookName)
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)
                    Text(item.zh)
                        .dsType(DS.Font.serifBody, lineSpacing: 6, tracking: 0.05)
                }

                let columns = [GridItem(.adaptive(minimum: 140), spacing: DS.Spacing.md)]
                LazyVGrid(columns: columns, alignment: .leading, spacing: DS.Spacing.md2) {
                    badge(icon: "text.book.closed", label: LocalizedStringKey("難度"), value: difficultyToRoman(item.difficulty))
                    badge(icon: "arrow.triangle.2.circlepath", label: LocalizedStringKey("練習次數"), value: "\(stats.attempts)")
                    badge(icon: "star.fill", label: LocalizedStringKey("最高分"), value: stats.bestScore.map(String.init) ?? "--")
                    badge(icon: "chart.line.uptrend.xyaxis", label: LocalizedStringKey("平均分"), value: stats.attempts > 0 ? String(format: "%.1f", stats.averageScore) : "--")
                }
                .dsAnimation(DS.AnimationToken.subtle, value: stats.attempts)
            }
            .padding(DS.Spacing.md)
        }
    }

    private func badge(icon: String, label: LocalizedStringKey, value: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
            HStack(spacing: DS.Spacing.xs2) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DS.Palette.primary)
                Text(label)
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .dsType(DS.Font.bodyEmph)
        }
    }
}
