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
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Progress indicator showing total items (using original design)
            if !allItemsWithBook.isEmpty {
                let total = filteredAndSortedItems.count
                DSOutlineCard {
                    HStack(alignment: .center) {
                        Text(String(localized: "label.progress", locale: locale))
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                        ProgressView(value: 0, total: Double(max(total, 1)))
                            .tint(DS.Palette.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                        Text("0 / \(total)")
                            .dsType(DS.Font.caption)
                    }
                    .padding(.vertical, 2)
                }
            }

            // Filter and Sort Controls (using original layout from LocalBankListView)
            if !allItemsWithBook.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        // All items chip (like original design)
                        DSFilterChip(
                            label: "全部",
                            count: allItemsWithBook.count,
                            color: DS.Palette.primary,
                            selected: selectedDifficulties.isEmpty && !tagFilterState.hasActiveFilters,
                            action: {
                                selectedDifficulties.removeAll()
                                tagFilterState.clear()
                            }
                        )

                        // Difficulty filters (using Roman numerals)
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
                    }
                    .padding(.horizontal, 2)
                }

                HStack {
                    // Sort picker (original style)
                    BankItemSortPicker(selectedSort: $sortOption)

                    Spacer()

                    // Tag filter button
                    Button("標籤篩選") {
                        showTagFilter = true
                    }
                    .buttonStyle(DSSecondaryButtonCompact())
                }
            }

            // Items list using original card design
            if filteredAndSortedItems.isEmpty {
                EmptyStateCard(
                    title: localBank.books.isEmpty ? String(localized: "bank.local.empty", locale: locale) : "無符合條件的項目",
                    subtitle: localBank.books.isEmpty ? String(localized: "cloud.books.subtitle", locale: locale) : "請調整篩選條件",
                    iconSystemName: "books.vertical"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: DS.Spacing.sm2) {
                        ForEach(filteredAndSortedItems, id: \.0.id) { item, bookName in
                            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                // Chinese text card
                                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                    HStack {
                                        // Book name indicator
                                        Text(bookName)
                                            .dsType(DS.Font.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        // Difficulty badge using original design
                                        Text(difficultyToRoman(item.difficulty))
                                            .dsType(DS.Font.labelSm)
                                            .foregroundStyle(DS.Palette.primary.opacity(0.8))
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 2)
                                            .background(
                                                Capsule().fill(DS.Palette.primary.opacity(0.1))
                                            )
                                    }

                                    Text(item.zh)
                                        .dsType(DS.Font.body)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(DS.Spacing.md)
                                .background(DS.Palette.surface, in: RoundedRectangle(cornerRadius: DS.Radius.lg))
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                                        .stroke(DS.Palette.border.opacity(DS.Opacity.muted), lineWidth: DS.BorderWidth.regular)
                                        .background(DS.Palette.surface.opacity(0.0001))
                                )

                                // Bottom row with tags and practice button (original design)
                                HStack(alignment: .center, spacing: 8) {
                                    HStack(spacing: 8) {
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
                                            Text(String(localized: "action.practice", locale: locale))
                                                .dsType(DS.Font.caption)
                                                .foregroundStyle(DS.Palette.primary)
                                        }
                                        .buttonStyle(DSSecondaryButtonCompact())
                                    }
                                }
                                .padding(.horizontal, DS.Spacing.md)

                                // Expandable hints section (original design)
                                if !item.hints.isEmpty {
                                    DisclosureGroup(
                                        isExpanded: Binding(
                                            get: { expanded.contains(item.id) },
                                            set: { isExpanded in
                                                if isExpanded {
                                                    expanded.insert(item.id)
                                                } else {
                                                    expanded.remove(item.id)
                                                }
                                            }
                                        )
                                    ) {
                                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                                            ForEach(item.hints, id: \.id) { hint in
                                                HStack(spacing: 8) {
                                                    Circle()
                                                        .fill(hint.category.color)
                                                        .frame(width: 8, height: 8)
                                                    Text(hint.text)
                                                        .dsType(DS.Font.caption)
                                                        .foregroundStyle(.secondary)
                                                    Spacer()
                                                }
                                            }
                                        }
                                        .padding(.horizontal, DS.Spacing.md)
                                        .padding(.bottom, DS.Spacing.sm)
                                    } label: {
                                        HStack {
                                            Image(systemName: "lightbulb")
                                                .foregroundStyle(DS.Palette.primary)
                                            Text(String(localized: "hints.title", locale: locale))
                                                .dsType(DS.Font.caption)
                                            Text("\(item.hints.count)")
                                                .dsType(DS.Font.caption)
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                        }
                                        .padding(.horizontal, DS.Spacing.md)
                                        .padding(.vertical, DS.Spacing.sm)
                                        .background(DS.Palette.surface.opacity(0.5))
                                    }
                                    .dsAnimation(DS.AnimationToken.subtle, value: expanded.contains(item.id))
                                }
                            }
                        }
                    }
                    .padding(.bottom, DS.Spacing.lg)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.top, DS.Spacing.lg)
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

// Completion badge for completed items
private struct CompletionBadge: View {
    @Environment(\.locale) private var locale
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.caption)
                .foregroundStyle(DS.Palette.success)
            Text(String(localized: "label.completed", locale: locale))
                .dsType(DS.Font.caption)
                .foregroundStyle(DS.Palette.success)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(DS.Palette.success.opacity(0.1), in: Capsule())
    }
}