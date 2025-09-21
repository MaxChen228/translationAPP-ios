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

private func difficultyColor(_ difficulty: Int) -> Color {
    switch difficulty {
    case 1: return DS.Palette.success
    case 2: return DS.Brand.scheme.cornhusk
    case 3: return DS.Brand.scheme.peachQuartz
    case 4: return DS.Palette.warning
    case 5: return DS.Palette.danger
    default: return DS.Palette.neutral
    }
}

struct AllBankItemsView: View {
    @ObservedObject var vm: CorrectionViewModel
    // Optional override: when provided, caller controls where the practice item goes
    var onPractice: ((String, BankItem, String?) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var localBank: LocalBankStore
    @EnvironmentObject private var localProgress: LocalBankProgressStore
    @State private var expanded: Set<String> = []
    @State private var selectedDifficulties: Set<Int> = []
    @State private var tagFilterState = TagFilterState()
    @State private var sortOption: BankItemSortOption = .defaultOrder
    @State private var showTagFilter: Bool = false
    @Environment(\.locale) private var locale

    // Combined items from all books with their source book name
    private var allItemsWithBook: [(BankItem, String)] {
        var items: [(BankItem, String)] = []
        for book in localBank.books {
            for item in book.items {
                items.append((item, book.name))
            }
        }
        return items
    }

    private var filteredAndSortedItems: [(BankItem, String)] {
        var filtered = allItemsWithBook

        // Difficulty filter
        if !selectedDifficulties.isEmpty {
            filtered = filtered.filter { selectedDifficulties.contains($0.0.difficulty) }
        }

        // Tag filter using new nested filter
        if tagFilterState.hasActiveFilters {
            filtered = filtered.filter { item in
                tagFilterState.matches(tags: item.0.tags ?? [])
            }
        }

        // Apply sorting - we need to handle multiple books differently
        let sortedItems = filtered.sorted { lhs, rhs in
            let (item1, book1) = lhs
            let (item2, book2) = rhs

            switch sortOption {
            case .defaultOrder:
                // Sort by book name first, then maintain original order
                if book1 != book2 {
                    return book1.localizedCompare(book2) == .orderedAscending
                }
                return false

            case .difficultyLowToHigh:
                return item1.difficulty < item2.difficulty

            case .difficultyHighToLow:
                return item1.difficulty > item2.difficulty

            case .completionIncomplete:
                let completed1 = localProgress.isCompleted(book: book1, itemId: item1.id)
                let completed2 = localProgress.isCompleted(book: book2, itemId: item2.id)
                if completed1 != completed2 {
                    return !completed1 // incomplete first
                }
                return false

            case .completionComplete:
                let completed1 = localProgress.isCompleted(book: book1, itemId: item1.id)
                let completed2 = localProgress.isCompleted(book: book2, itemId: item2.id)
                if completed1 != completed2 {
                    return completed1 // completed first
                }
                return false

            case .tagsAlphabetical:
                let tag1 = item1.tags?.first ?? ""
                let tag2 = item2.tags?.first ?? ""
                return tag1.localizedCompare(tag2) == .orderedAscending
            }
        }

        return sortedItems
    }

    private var difficultyStats: [(Int, Int)] {
        let allItems = allItemsWithBook.map { $0.0 }
        let grouped = Dictionary(grouping: allItems, by: { $0.difficulty })
        return (1...5).compactMap { difficulty in
            guard let items = grouped[difficulty], !items.isEmpty else { return nil }
            return (difficulty, items.count)
        }
    }

    private var tagStats: [String: Int] {
        let allTags = allItemsWithBook.flatMap { $0.0.tags ?? [] }
        return Dictionary(allTags.map { ($0, 1) }, uniquingKeysWith: +)
    }

    var body: some View {
        let items = filteredAndSortedItems
        let allItems = allItemsWithBook
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                // Progress indicator showing total items (using original design)
                if !allItems.isEmpty {
                    let completed = items.filter { item, bookName in
                        localProgress.isCompleted(book: bookName, itemId: item.id)
                    }.count
                    let total = items.count

                    DSOutlineCard {
                        HStack(alignment: .center) {
                            Text(String(localized: "label.progress", locale: locale))
                                .dsType(DS.Font.caption)
                                .foregroundStyle(.secondary)
                            ProgressView(value: Double(completed), total: Double(max(total, 1)))
                                .tint(DS.Palette.primary)
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 8)
                            Text("\(completed) / \(total)")
                                .dsType(DS.Font.caption)
                        }
                        .padding(.vertical, 2)
                    }
                }

                // Filter and Sort Controls
                if !allItems.isEmpty {
                    VStack(spacing: DS.Spacing.sm) {
                        // Quick filter chips row
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // All filter (clear filters)
                                DSFilterChip(
                                    label: "filter.all",
                                    count: allItems.count,
                                    color: DS.Palette.neutral,
                                    selected: selectedDifficulties.isEmpty && !tagFilterState.hasActiveFilters
                                ) {
                                    selectedDifficulties.removeAll()
                                    tagFilterState.clear()
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

                                // Advanced tag filter button
                                Button {
                                    showTagFilter = true
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "tag")
                                        Text("標籤篩選")
                                        if tagFilterState.hasActiveFilters {
                                            Text("(\(tagFilterState.selectedTags.count))")
                                                .dsType(DS.Font.caption)
                                        }
                                    }
                                    .dsType(DS.Font.labelSm)
                                    .foregroundStyle(tagFilterState.hasActiveFilters ? DS.Palette.primary : .primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        Capsule()
                                            .fill(tagFilterState.hasActiveFilters ? DS.Palette.primary.opacity(DS.Opacity.fill) : DS.Palette.surface)
                                    )
                                    .overlay(
                                        Capsule()
                                            .stroke(
                                                tagFilterState.hasActiveFilters ? DS.Palette.primary.opacity(0.3) : DS.Palette.border.opacity(DS.Opacity.border),
                                                lineWidth: DS.BorderWidth.thin
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
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

                // Empty states
                if items.isEmpty && !allItems.isEmpty {
                    EmptyStateCard(
                        title: String(localized: "filter.noResults", locale: locale),
                        subtitle: String(localized: "filter.noResults.hint", locale: locale),
                        iconSystemName: "line.3.horizontal.decrease.circle"
                    )
                } else if allItems.isEmpty {
                    EmptyStateCard(
                        title: localBank.books.isEmpty ? String(localized: "bank.local.empty", locale: locale) : "無符合條件的項目",
                        subtitle: localBank.books.isEmpty ? String(localized: "cloud.books.subtitle", locale: locale) : "請調整篩選條件",
                        iconSystemName: "books.vertical"
                    )
                }

                // Items list using exact LocalBankListView structure
                ForEach(items.indices, id: \.self) { i in
                    if i > 0 {
                        DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(DS.Opacity.border)).padding(.vertical, DS.Spacing.sm)
                    }
                    let (item, bookName) = items[i]
                    VStack(alignment: .leading, spacing: 10) {
                        // Main content card - Chinese text
                        Text(item.zh)
                            .dsType(DS.Font.serifTitle, lineSpacing: 6, tracking: 0.1)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 12)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                                    .stroke(DS.Palette.border.opacity(DS.Opacity.muted), lineWidth: DS.BorderWidth.regular)
                                    .background(DS.Palette.surface.opacity(0.0001))
                            )

                        // Bottom row with difficulty, tags, and practice button
                        HStack(alignment: .center, spacing: 8) {
                            HStack(spacing: 8) {
                                // Difficulty badge
                                Text(difficultyToRoman(item.difficulty))
                                    .dsType(DS.Font.labelSm)
                                    .foregroundStyle(DS.Palette.primary.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule().fill(DS.Palette.primary.opacity(0.1))
                                    )

                                // Book name
                                Text(bookName)
                                    .dsType(DS.Font.caption)
                                    .foregroundStyle(.secondary)

                                // Tags
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
                                    handlePractice(bookName: bookName, item: item, tag: item.tags?.first)
                                } label: {
                                    Label {
                                        Text(String(localized: "action.practice", locale: locale))
                                    } icon: {
                                        Image(systemName: "play.fill")
                                    }
                                }
                                .buttonStyle(DSButton(style: .secondary, size: .compact))
                            }
                        }

                        // Hints section
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
        .navigationTitle("所有題庫")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showTagFilter) {
            NavigationStack {
                ScrollView {
                    NestedTagFilterView(
                        filterState: $tagFilterState,
                        tagStats: tagStats
                    )
                    .padding(.vertical, DS.Spacing.lg)
                }
                .background(DS.Palette.background)
                .navigationTitle("標籤篩選")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") {
                            showTagFilter = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func handlePractice(bookName: String, item: BankItem, tag: String?) {
        if let external = onPractice {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                external(bookName, item, tag)
            }
        } else {
            vm.bindLocalBankStores(localBank: localBank, progress: localProgress)
            vm.startLocalPractice(bookName: bookName, item: item, tag: tag)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { dismiss() }
        }
    }
}

// Completion badge for completed items (matching LocalBankListView style)
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