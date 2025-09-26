import SwiftUI

struct RandomPracticeBookScopeView: View {
    @EnvironmentObject private var settings: RandomPracticeStore
    @EnvironmentObject private var localBank: LocalBankStore
    @EnvironmentObject private var folders: BankFoldersStore
    @Environment(\.locale) private var locale

    @State private var expandedFolders: Set<UUID> = []

    private var selectionContext: (raw: Set<String>, active: Set<String>, available: Set<String>) {
        let available = Set(localBank.books.map { $0.name })
        let normalized = settings.normalizedBookScope(with: available)
        let active = normalized.isEmpty ? available : normalized
        return (normalized, active, available)
    }

    private var bookLookup: [String: LocalBankBook] {
        Dictionary(uniqueKeysWithValues: localBank.books.map { ($0.name, $0) })
    }

    private var folderList: [BankFolder] {
        folders.folders.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private var rootBooks: [LocalBankBook] {
        localBank.books
            .filter { !folders.isInAnyFolder($0.name) }
            .sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private var selectedCountText: String {
        let context = selectionContext
        guard !context.available.isEmpty else {
            return String(localized: "bank.random.scope.summary.empty")
        }
        if context.raw.isEmpty {
            return String(localized: "bank.random.scope.summary.all")
        }
        return String(
            format: String(localized: "bank.random.scope.summary.count"),
            Int64(context.active.count),
            Int64(context.available.count)
        )
    }

    private var selectionPreviewText: String? {
        let context = selectionContext
        guard !context.available.isEmpty, !context.raw.isEmpty else { return nil }
        let names = Array(context.active).sorted()
        let preview = names.prefix(3)
        guard !preview.isEmpty else { return nil }
        let previewText = preview.joined(separator: String(localized: "bank.random.scope.preview.separator"))
        let remainder = names.count - preview.count
        if remainder <= 0 {
            return previewText
        }
        return previewText + String(
            format: String(localized: "bank.random.scope.preview.more"),
            Int64(remainder)
        )
    }

    var body: some View {
        let context = selectionContext
        Group {
            if context.available.isEmpty {
                EmptyStateCard(
                    title: String(localized: "bank.random.scope.empty.title"),
                    subtitle: String(localized: "bank.random.scope.empty.subtitle"),
                    iconSystemName: "books.vertical"
                )
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                        summaryCard

                        if !folderList.isEmpty {
                            folderSection
                        }

                        uncategorizedSection
                    }
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, DS.Spacing.lg)
                }
                .background(DS.Palette.background)
            }
        }
        .navigationTitle(Text("bank.random.scope.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(String(localized: "bank.random.scope.summary.title"))
                    .dsType(DS.Font.section)

                Text(selectedCountText)
                    .dsType(DS.Font.body)
                    .foregroundStyle(.secondary)

                if let preview = selectionPreviewText {
                    Text(preview)
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.tertiary)
                }

                Button {
                    settings.setSelectedBooks([])
                } label: {
                    Label {
                        Text(String(localized: "bank.random.scope.selectAll"))
                    } icon: {
                        Image(systemName: "checkmark.circle")
                    }
                }
                .buttonStyle(DSButton(style: .secondary, size: .compact))
                .padding(.top, DS.Spacing.xs)
            }
        }
    }

    private var folderSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
            DSSectionHeader(titleKey: "bank.random.scope.section.folders", accentUnderline: true)

            LazyVStack(spacing: DS.Spacing.sm2) {
                ForEach(folderList) { folder in
                    folderCard(for: folder)
                }
            }
        }
    }

    private var uncategorizedSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
            DSSectionHeader(titleKey: "bank.random.scope.section.standalone", accentUnderline: true)

            if rootBooks.isEmpty {
                DSOutlineCard {
                    Text(String(localized: "bank.random.scope.section.empty"))
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                LazyVStack(spacing: DS.Spacing.sm2) {
                    ForEach(rootBooks) { book in
                        bookRow(book)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func folderCard(for folder: BankFolder) -> some View {
        let books = folder.bookNames.compactMap { bookLookup[$0] }
        let totalCount = books.count
        let selectedNames = selectionContext.active
        let isSelected = totalCount > 0 && books.allSatisfy { selectedNames.contains($0.name) }
        let selectedCount = books.filter { selectedNames.contains($0.name) }.count
        let isPartial = selectedCount > 0 && selectedCount < totalCount
        let isExpanded = expandedFolders.contains(folder.id)

        DSOutlineCard(padding: 0) {
            VStack(spacing: 0) {
                HStack(spacing: DS.Spacing.sm) {
                    ScopeSelectionIndicator(state: indicatorState(isSelected: isSelected, isPartial: isPartial))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(folder.name)
                            .dsType(DS.Font.bodyEmph)
                            .foregroundStyle(.primary)

                        Text(
                            String(
                                format: String(localized: "bank.folder.count", locale: locale),
                                Int64(books.count)
                            )
                        )
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        toggleFolderExpansion(folder.id)
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: DS.IconSize.chevronSm, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(totalCount == 0)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm2)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard totalCount > 0 else { return }
                    toggleFolderSelection(books: books, totalCount: totalCount, selectedCount: selectedCount)
                }
                .allowsHitTesting(totalCount > 0)

                if isExpanded && !books.isEmpty {
                    Divider()
                        .padding(.leading, DS.Spacing.md + 20)

                    LazyVStack(spacing: 0) {
                        ForEach(books) { book in
                            bookRow(book)
                                .padding(.leading, DS.Spacing.md)
                        }
                    }
                    .padding(.bottom, DS.Spacing.xs)
                }
            }
        }
        .opacity(totalCount == 0 ? 0.4 : 1)
    }

    @ViewBuilder
    private func bookRow(_ book: LocalBankBook) -> some View {
        let isSelected = selectionContext.active.contains(book.name)

        Button {
            toggleBookSelection(book.name)
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                ScopeSelectionIndicator(state: isSelected ? .selected : .unselected)

                VStack(alignment: .leading, spacing: 2) {
                    Text(book.name)
                        .dsType(DS.Font.body)
                        .foregroundStyle(.primary)

                    Text(
                        String(
                            format: String(localized: "bank.book.count", locale: locale),
                            book.items.count
                        )
                    )
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(isSelected ? DS.Palette.primary.opacity(DS.Opacity.fill) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(
                    isSelected ? DS.Palette.primary : DS.Palette.border.opacity(DS.Opacity.border),
                    lineWidth: isSelected ? DS.BorderWidth.regular : DS.BorderWidth.hairline
                )
        )
    }

    private func toggleFolderSelection(books: [LocalBankBook], totalCount: Int, selectedCount: Int) {
        let context = selectionContext
        var updated = context.active
        if selectedCount == totalCount {
            for book in books { updated.remove(book.name) }
        } else {
            for book in books { updated.insert(book.name) }
        }
        applySelection(updated, available: context.available)
    }

    private func toggleBookSelection(_ name: String) {
        let context = selectionContext
        var updated = context.active
        if updated.contains(name) {
            updated.remove(name)
        } else {
            updated.insert(name)
        }
        applySelection(updated, available: context.available)
    }

    private func toggleFolderExpansion(_ id: UUID) {
        if expandedFolders.contains(id) {
            expandedFolders.remove(id)
        } else {
            expandedFolders.insert(id)
        }
    }

    private func applySelection(_ newValue: Set<String>, available: Set<String>) {
        if newValue.isEmpty || newValue == available {
            settings.setSelectedBooks([])
        } else {
            settings.setSelectedBooks(newValue)
        }
    }

    private func indicatorState(isSelected: Bool, isPartial: Bool) -> ScopeSelectionIndicator.State {
        if isSelected { return .selected }
        if isPartial { return .partial }
        return .unselected
    }
}

private struct ScopeSelectionIndicator: View {
    enum State {
        case selected
        case partial
        case unselected
    }

    var state: State

    var body: some View {
        let color = DS.Palette.primary
        return Group {
            switch state {
            case .selected:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(color)
            case .partial:
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(color.opacity(0.7))
            case .unselected:
                Image(systemName: "circle")
                    .foregroundStyle(DS.Palette.border)
            }
        }
        .font(.system(size: 18, weight: .medium))
    }
}
