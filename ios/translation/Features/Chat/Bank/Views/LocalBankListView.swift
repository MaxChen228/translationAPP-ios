import SwiftUI

struct LocalBankListView: View {
    @ObservedObject var vm: CorrectionViewModel
    let bookName: String
    // Optional override: when provided, caller controls where the practice item goes
    var onPractice: ((BankItem, String?) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localBank: LocalBankStore
    @EnvironmentObject private var localProgress: LocalBankProgressStore
    @State private var expanded: Set<String> = []
    @State private var selectedDifficulties: Set<Int> = []
    @State private var selectedTags: Set<String> = []
    @State private var sortOption: BankItemSortOption = .defaultOrder
    @Environment(\.locale) private var locale

    private var filteredAndSortedItems: [BankItem] {
        let allItems = localBank.items(in: bookName)

        // Apply filters
        var filtered = allItems

        // Difficulty filter
        if !selectedDifficulties.isEmpty {
            filtered = filtered.filter { selectedDifficulties.contains($0.difficulty) }
        }

        // Tag filter
        if !selectedTags.isEmpty {
            filtered = filtered.filter { item in
                guard let tags = item.tags else { return false }
                return !Set(tags).isDisjoint(with: selectedTags)
            }
        }

        // Apply sorting
        return BankItemSortPicker.sortItems(filtered, by: sortOption, progressStore: localProgress, bookName: bookName)
    }

    private var difficultyStats: [(Int, Int)] {
        let allItems = localBank.items(in: bookName)
        let grouped = Dictionary(grouping: allItems, by: { $0.difficulty })
        return (1...5).compactMap { difficulty in
            guard let items = grouped[difficulty], !items.isEmpty else { return nil }
            return (difficulty, items.count)
        }
    }

    private var tagStats: [(String, Int)] {
        let allItems = localBank.items(in: bookName)
        let allTags = allItems.compactMap { $0.tags }.flatMap { $0 }
        let grouped = Dictionary(grouping: allTags, by: { $0 })
        return grouped.compactMap { tag, occurrences in
            (tag, occurrences.count)
        }.sorted { $0.0 < $1.0 }
    }

    var body: some View {
        let items = filteredAndSortedItems
        let allItems = localBank.items(in: bookName)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // 頂部進度摘要：顯示「已完成 / 題數」
                if !allItems.isEmpty {
                    let done = allItems.filter { localProgress.isCompleted(book: bookName, itemId: $0.id) }.count
                    let total = allItems.count
                    DSOutlineCard {
                        HStack(alignment: .center) {
                            Text(String(localized: "label.progress", locale: locale))
                                .dsType(DS.Font.caption)
                                .foregroundStyle(.secondary)
                            ProgressView(value: Double(done), total: Double(max(total, 1)))
                                .tint(DS.Palette.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 8)
                            Text("\(done) / \(total)")
                                .dsType(DS.Font.caption)
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Filter and Sort Controls
                if !allItems.isEmpty {
                    VStack(spacing: DS.Spacing.sm) {
                        // Filter chips row
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // All filter (clear filters)
                                DSFilterChip(
                                    label: "filter.all",
                                    count: allItems.count,
                                    color: DS.Palette.neutral,
                                    selected: selectedDifficulties.isEmpty && selectedTags.isEmpty
                                ) {
                                    selectedDifficulties.removeAll()
                                    selectedTags.removeAll()
                                }

                                // Difficulty filters
                                ForEach(difficultyStats, id: \.0) { difficulty, count in
                                    DSDifficultyFilterChip(
                                        difficulty: difficulty,
                                        count: count,
                                        selected: selectedDifficulties.contains(difficulty)
                                    ) {
                                        if selectedDifficulties.contains(difficulty) {
                                            selectedDifficulties.remove(difficulty)
                                        } else {
                                            selectedDifficulties.insert(difficulty)
                                        }
                                    }
                                }

                                // Tag filters
                                ForEach(tagStats, id: \.0) { tag, count in
                                    DSTagFilterChip(
                                        tag: tag,
                                        count: count,
                                        selected: selectedTags.contains(tag)
                                    ) {
                                        if selectedTags.contains(tag) {
                                            selectedTags.remove(tag)
                                        } else {
                                            selectedTags.insert(tag)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 2)
                        }

                        // Sort control
                        HStack {
                            if items.count != allItems.count {
                                Text(String(format: String(localized: "filter.showing", locale: locale), items.count, allItems.count))
                                    .dsType(DS.Font.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            BankItemSortPicker(selectedSort: $sortOption)
                        }
                    }
                }

                if items.isEmpty && !allItems.isEmpty {
                    EmptyStateCard(
                        title: String(localized: "filter.noResults", locale: locale),
                        subtitle: String(localized: "filter.noResults.hint", locale: locale),
                        iconSystemName: "line.3.horizontal.decrease.circle"
                    )
                } else if allItems.isEmpty {
                    EmptyStateCard(title: String(localized: "bank.book.empty", locale: locale), subtitle: String(localized: "bank.book.empty.hint", locale: locale), iconSystemName: "text.book.closed")
                }
                ForEach(items.indices, id: \.self) { i in
                    if i > 0 {
                        DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(DS.Opacity.border)).padding(.vertical, DS.Spacing.sm)
                    }
                    let item = items[i]
                    VStack(alignment: .leading, spacing: 10) {
                        Text(item.zh)
                            .dsType(DS.Font.serifTitle, lineSpacing: 6, tracking: 0.1)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                    .stroke(DS.Palette.border.opacity(DS.Opacity.muted), lineWidth: DS.BorderWidth.regular)
                                    .background(DS.Palette.surface.opacity(0.0001))
                            )
                        HStack(alignment: .center, spacing: 8) {
                            HStack(spacing: 8) {
                                HStack(spacing: 4) {
                                    ForEach(1...5, id: \.self) { j in
                                        Circle().fill(j <= item.difficulty ? DS.Palette.primary.opacity(0.8) : DS.Palette.border.opacity(DS.Opacity.border))
                                            .frame(width: 6, height: 6)
                                    }
                                }
                                if let tags = item.tags, !tags.isEmpty {
                                    Text(tags.joined(separator: ", "))
                                        .dsType(DS.Font.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                            if localProgress.isCompleted(book: bookName, itemId: item.id) {
                                CompletionBadge()
                            } else {
                                Button {
                                    if let onPractice {
                                        onPractice(item, item.tags?.first)
                                        // 關閉本清單頁，與遠端列表行為一致（外層 handler 還會再關閉上一層頁面）
                                        dismiss()
                                    } else {
                                        vm.bindLocalBankStores(localBank: localBank, progress: localProgress)
                                        vm.startLocalPractice(bookName: bookName, item: item, tag: item.tags?.first)
                                        dismiss()
                                    }
                                } label: { Label { Text("action.practice") } icon: { Image(systemName: "play.fill") } }
                                    .buttonStyle(DSSecondaryButtonCompact())
                            }
                        }
                        HintListSection(
                            hints: item.hints,
                            isExpanded: Binding(
                                get: { expanded.contains(item.id) },
                                set: { v in if v { expanded.insert(item.id) } else { expanded.remove(item.id) } }
                            )
                        )
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.top, DS.Spacing.lg)
            .padding(.bottom, DS.Spacing.lg)
        }
        .background(DS.Palette.background)
        .navigationTitle(bookName)
    }
}

// 重用遠端清單的完成徽章樣式
private struct CompletionBadge: View {
    @Environment(\.locale) private var locale
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
            Text(String(localized: "label.completed", locale: locale))
        }
        .font(.subheadline)
        .foregroundStyle(DS.Palette.primary)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Capsule().fill(Color.clear))
        .overlay(Capsule().stroke(DS.Palette.primary.opacity(DS.Opacity.strong), lineWidth: DS.BorderWidth.regular))
        .accessibilityLabel(Text("label.completed"))
    }
}
