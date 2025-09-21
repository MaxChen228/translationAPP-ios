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
}
