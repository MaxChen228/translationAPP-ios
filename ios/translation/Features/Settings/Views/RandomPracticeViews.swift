import SwiftUI

struct RandomPracticeToolbarButton: View {
    var action: () -> Void
    var body: some View {
        DSQuickActionIconButton(systemName: "die.face.5", labelKey: "bank.random.title", action: action, shape: .circle, size: 28)
    }
}

struct RandomSettingsToolbarButton: View {
    var onOpen: () -> Void
    var body: some View {
        DSQuickActionIconButton(systemName: "gearshape", labelKey: "bank.random.settings", action: onOpen, shape: .circle, size: 28)
    }
}

struct RandomPracticeSettingsSheet: View {
    @EnvironmentObject private var settings: RandomPracticeStore
    @EnvironmentObject private var localBank: LocalBankStore
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
