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

    private var bookScopeContext: (raw: Set<String>, available: Set<String>) {
        let available = Set(localBank.books.map { $0.name })
        let raw = settings.normalizedBookScope(with: available)
        return (raw, available)
    }

    private var scopedBooks: [LocalBankBook] {
        let context = bookScopeContext
        let allowed = context.raw.isEmpty ? context.available : context.raw
        guard !allowed.isEmpty else { return [] }
        return localBank.books.filter { allowed.contains($0.name) }
    }

    private var hasCustomScope: Bool {
        !bookScopeContext.raw.isEmpty && !bookScopeContext.available.isEmpty
    }

    private var bookScopeSummaryText: String {
        let context = bookScopeContext
        guard !context.available.isEmpty else {
            return String(localized: "bank.random.scope.summary.empty")
        }
        if context.raw.isEmpty {
            return String(localized: "bank.random.scope.summary.all")
        }
        return String(
            format: String(localized: "bank.random.scope.summary.count"),
            Int64(context.raw.count),
            Int64(context.available.count)
        )
    }

    private var bookScopePreviewText: String? {
        let context = bookScopeContext
        guard !context.available.isEmpty, !context.raw.isEmpty else { return nil }
        let names = Array(context.raw).sorted()
        let preview = names.prefix(3)
        guard !preview.isEmpty else { return nil }
        let separator = String(localized: "bank.random.scope.preview.separator")
        let previewText = preview.joined(separator: separator)
        let remainder = names.count - preview.count
        if remainder <= 0 {
            return previewText
        }
        return previewText + String(
            format: String(localized: "bank.random.scope.preview.more"),
            Int64(remainder)
        )
    }

    private var scopeSelectorCard: some View {
        let accent = DS.Palette.primary
        let fillColor = hasCustomScope ? accent.opacity(DS.Opacity.fill) : nil
        return DSOutlineCard(padding: DS.Spacing.sm2, fill: fillColor) {
            HStack(alignment: .center, spacing: DS.Spacing.sm) {
                Image(systemName: hasCustomScope ? "checkmark.circle" : "books.vertical")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(hasCustomScope ? accent : .secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "bank.random.scope.selector.title"))
                        .dsType(DS.Font.bodyEmph)
                        .foregroundStyle(.primary)

                    Text(bookScopeSummaryText)
                        .dsType(DS.Font.caption)
                        .foregroundStyle(hasCustomScope ? accent : .secondary)

                    if let preview = bookScopePreviewText {
                        Text(preview)
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: DS.IconSize.chevronSm, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, DS.Spacing.sm)
        }
    }

    private var tagStats: [String: Int] {
        scopedBooks
            .flatMap { $0.items }
            .compactMap { $0.tags }
            .flatMap { $0 }
            .reduce(into: [:]) { partialResult, tag in
                partialResult[tag, default: 0] += 1
            }
    }

    private var allItems: [BankItem] {
        scopedBooks.flatMap { $0.items }
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

        return scopedBooks.reduce(into: 0) { acc, book in
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

                    NavigationLink {
                        RandomPracticeBookScopeView()
                    } label: {
                        scopeSelectorCard
                    }
                    .buttonStyle(.plain)

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
