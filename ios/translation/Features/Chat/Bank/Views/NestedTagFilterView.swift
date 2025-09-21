import SwiftUI

struct NestedTagFilterView: View {
    @Binding var filterState: TagFilterState
    let tagStats: [String: Int]
    @Environment(\.locale) private var locale

    private var categoryStats: [TagCategory: Int] {
        var stats: [TagCategory: Int] = [:]
        for category in TagCategory.allCases {
            let categoryTags = TagRegistry.tags(for: category)
            let count = categoryTags.compactMap { tag in
                let tagCount = tagStats[tag] ?? 0
                return tagCount > 0 ? tagCount : nil
            }.reduce(0, +)
            stats[category] = count
        }
        return stats
    }

    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            filterHeader

            if filterState.hasActiveFilters {
                activeFiltersCard
            }

            LazyVStack(spacing: DS.Spacing.md) {
                ForEach(TagCategory.allCases) { category in
                    ExpandableTagCategoryView(
                        category: category,
                        filterState: $filterState,
                        tagStats: tagStats,
                        categoryCount: categoryStats[category] ?? 0
                    )
                }
            }
        }
    }

    private var filterHeader: some View {
        DSSectionHeader(
            verbatimTitle: "篩選標籤",
            accentUnderline: true,
            accentLines: 2,
            accentSpacing: 2
        )
        .overlay(alignment: .topTrailing) {
            if filterState.hasActiveFilters {
                Button("清除全部") {
                    filterState.clear()
                }
                .buttonStyle(DSButton(style: .secondary, size: .compact))
            }
        }
    }

    private var activeFiltersCard: some View {
        DSCard(padding: DS.Spacing.sm2) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text("已選擇 \(filterState.selectedTags.count) 個標籤")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(filterState.selectedTags).sorted(), id: \.self) { tag in
                            ActiveFilterChip(
                                tag: tag,
                                count: tagStats[tag] ?? 0
                            ) {
                                filterState.toggleTag(tag)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
        .transition(DSTransition.cardExpand)
    }
}

struct ExpandableTagCategoryView: View {
    let category: TagCategory
    @Binding var filterState: TagFilterState
    let tagStats: [String: Int]
    let categoryCount: Int
    @Environment(\.locale) private var locale

    private var isExpanded: Bool {
        filterState.isExpanded.contains(category)
    }

    private var categoryTags: [String] {
        TagRegistry.tags(for: category).filter { tag in
            (tagStats[tag] ?? 0) > 0
        }
    }

    private var isCategorySelected: Bool {
        filterState.selectedCategories.contains(category)
    }

    private var partialSelection: Bool {
        let categoryTagSet = Set(categoryTags)
        let selectedTagSet = filterState.selectedTags
        return !categoryTagSet.isDisjoint(with: selectedTagSet) &&
               !categoryTagSet.isSubset(of: selectedTagSet)
    }

    var body: some View {
        DSCard(
            padding: 0,
            fill: isCategorySelected ? category.color.lightColor : nil
        ) {
            VStack(spacing: 0) {
                categoryHeader

                if isExpanded {
                    tagGrid
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.95).combined(with: .opacity),
                            removal: .scale(scale: 0.95).combined(with: .opacity)
                        ))
                }
            }
        }
        .animation(DS.AnimationToken.snappy, value: isExpanded)
        .animation(DS.AnimationToken.subtle, value: isCategorySelected)
    }

    private var categoryHeader: some View {
        Button {
            if filterState.isExpanded.contains(category) {
                filterState.isExpanded.remove(category)
            } else {
                filterState.isExpanded.insert(category)
            }
        } label: {
            HStack(spacing: DS.Spacing.sm2) {
                DSQuickActionIconGlyph(
                    systemName: category.iconSystemName,
                    style: isCategorySelected ? .filled : .tinted,
                    size: 32
                )

                VStack(alignment: .leading, spacing: 2) {
                    Text(category.rawValue)
                        .dsType(DS.Font.bodyEmph)
                        .foregroundStyle(.primary)

                    Text("\(categoryTags.count) 個標籤 • \(categoryCount) 題")
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    categorySelectionIndicator

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: DS.IconSize.chevronSm, weight: .medium))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm2)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(isCategorySelected ? "取消選擇分類" : "選擇整個分類") {
                filterState.toggleCategory(category)
            }
        }
    }

    private var categorySelectionIndicator: some View {
        Group {
            if isCategorySelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(category.color.accentColor)
            } else if partialSelection {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(category.color.accentColor.opacity(0.6))
            } else {
                Image(systemName: "circle")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.system(size: 16))
    }

    private var tagGrid: some View {
        let selectedTagsSet = filterState.selectedTags

        return LazyVStack(spacing: 8) {
            let columns = 2
            ForEach(0..<(categoryTags.count + columns - 1) / columns, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        if index < categoryTags.count {
                            let tag = categoryTags[index]
                            CategoryTagChip(
                                tag: tag,
                                count: tagStats[tag] ?? 0,
                                category: category,
                                isSelected: selectedTagsSet.contains(tag)
                            ) {
                                filterState.toggleTag(tag)
                            }
                        } else {
                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.top, DS.Spacing.xs)
        .padding(.bottom, DS.Spacing.sm2)
    }
}

// 基於現有 DSFilterChip 的分類標籤 chip
struct CategoryTagChip: View {
    let tag: String
    let count: Int
    let category: TagCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        DSFilterChip(
            label: LocalizedStringKey(TagRegistry.localizedName(for: tag)),
            count: count,
            color: category.color.accentColor,
            selected: isSelected,
            action: onTap
        )
    }
}

struct ActiveFilterChip: View {
    let tag: String
    let count: Int
    let onRemove: () -> Void

    var body: some View {
        Button(action: onRemove) {
            HStack(spacing: 4) {
                Text(TagRegistry.localizedName(for: tag))
                    .dsType(DS.Font.labelSm)

                if count > 0 {
                    Text("(\(count))")
                        .dsType(DS.Font.caption)
                        .padding(.vertical, 1)
                        .padding(.horizontal, 4)
                        .background(Capsule().fill(DS.Palette.primary.opacity(0.15)))
                }

                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(DS.Palette.primary)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(
                Capsule().fill(DS.Palette.primary.opacity(DS.Opacity.fill))
            )
            .overlay(
                Capsule().stroke(DS.Palette.primary.opacity(0.3), lineWidth: DS.BorderWidth.thin)
            )
        }
        .buttonStyle(.plain)
        .dsAnimation(DS.AnimationToken.subtle, value: tag)
    }
}