import SwiftUI

struct RandomPracticeSettingsSheet: View {
    @EnvironmentObject private var settings: RandomPracticeStore
    @EnvironmentObject private var localBank: LocalBankStore
    @EnvironmentObject private var localProgress: LocalBankProgressStore
    @Environment(\.dismiss) private var dismiss

    private var filterBinding: Binding<TagFilterState> {
        Binding(
            get: { settings.filterState },
            set: { settings.filterState = $0 }
        )
    }

    private var tagStats: [String: Int] {
        localBank.books
            .flatMap { $0.items }
            .compactMap { $0.tags }
            .flatMap { $0 }
            .reduce(into: [:]) { partialResult, tag in
                partialResult[tag, default: 0] += 1
            }
    }

    private var allItems: [BankItem] {
        localBank.books.flatMap { $0.items }
    }

    private var difficultyStats: [(difficulty: Int, count: Int)] {
        let grouped = Dictionary(grouping: allItems, by: { $0.difficulty })
        return (1...5).map { difficulty in
            (difficulty, grouped[difficulty]?.count ?? 0)
        }
    }

    private var totalItemCount: Int {
        allItems.count
    }

    private var eligibleItemCount: Int {
        let filterState = settings.filterState
        let selectedDifficulties = settings.selectedDifficulties

        return localBank.books.reduce(into: 0) { acc, book in
            for item in book.items {
                if !selectedDifficulties.isEmpty && !selectedDifficulties.contains(item.difficulty) {
                    continue
                }
                if settings.excludeCompleted && localProgress.isCompleted(book: book.name, itemId: item.id) {
                    continue
                }
                if filterState.hasActiveFilters {
                    guard let tags = item.tags, !tags.isEmpty else { continue }
                    guard filterState.matches(tags: tags) else { continue }
                }
                acc += 1
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    DSSectionHeader(titleKey: "bank.random.settings", accentUnderline: true)

                    DSOutlineCard {
                        Toggle(isOn: $settings.excludeCompleted) {
                            Text("bank.random.excludeCompleted")
                        }
                    }

                    if totalItemCount > 0 {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text("bank.random.difficulty.title")
                                .dsType(DS.Font.caption)
                                .foregroundStyle(.secondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    DSFilterChip(
                                        label: "filter.all",
                                        count: totalItemCount,
                                        color: DS.Palette.neutral,
                                        selected: settings.selectedDifficulties.isEmpty
                                    ) {
                                        settings.selectedDifficulties.removeAll()
                                    }

                                    ForEach(difficultyStats, id: \.difficulty) { stat in
                                        let isDisabled = stat.count == 0
                                        DSDifficultyFilterChip(
                                            difficulty: stat.difficulty,
                                            count: stat.count,
                                            selected: settings.selectedDifficulties.contains(stat.difficulty)
                                        ) {
                                            toggleDifficulty(stat.difficulty)
                                        }
                                        .opacity(isDisabled ? 0.35 : 1)
                                        .disabled(isDisabled)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                    }

                    if totalItemCount > 0 {
                        Text(String(format: String(localized: "bank.random.eligibleCount"), Int64(eligibleItemCount)))
                            .dsType(DS.Font.caption)
                            .foregroundStyle(eligibleItemCount == 0 ? DS.Palette.danger : .secondary)
                    }

                    if tagStats.isEmpty {
                        EmptyStateCard(
                            title: String(localized: "bank.random.tags.empty.title"),
                            subtitle: String(localized: "bank.random.tags.empty.subtitle"),
                            iconSystemName: "tag"
                        )
                    } else {
                        NestedTagFilterView(
                            filterState: filterBinding,
                            tagStats: tagStats
                        )
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.lg)
            }
            .background(DS.Palette.background)
            .navigationTitle(Text("bank.random.settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: "action.done")) {
                        dismiss()
                    }
                    .buttonStyle(DSButton(style: .secondary, size: .compact))
                }
            }
        }
        .presentationDragIndicator(.visible)
    }

    private func toggleDifficulty(_ difficulty: Int) {
        if settings.selectedDifficulties.contains(difficulty) {
            settings.selectedDifficulties.remove(difficulty)
        } else {
            settings.selectedDifficulties.insert(difficulty)
        }
    }
}
