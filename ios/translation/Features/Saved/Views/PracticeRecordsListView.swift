import SwiftUI

struct PracticeRecordsListView: View {
    @EnvironmentObject private var store: PracticeRecordsStore
    @Environment(\.locale) private var locale
    private enum DeleteContext {
        case single(PracticeRecord)
        case clearAll

        var titleKey: LocalizedStringKey {
            switch self {
            case .single:
                return "practice.records.delete.confirm.title"
            case .clearAll:
                return "practice.records.clear.confirm.title"
            }
        }

        var messageKey: LocalizedStringKey {
            switch self {
            case .single:
                return "practice.records.delete.confirm.message"
            case .clearAll:
                return "practice.records.clear.confirm.message"
            }
        }

        var actionLabelKey: LocalizedStringKey {
            switch self {
            case .single:
                return "practice.records.delete.confirm.action"
            case .clearAll:
                return "practice.records.clear.confirm.action"
            }
        }
    }

    @State private var showDeleteConfirmation = false
    @State private var deleteContext: DeleteContext?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    if store.records.isEmpty {
                        DSOutlineCard {
                            VStack(spacing: DS.Spacing.lg) {
                                Image(systemName: "doc.text")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("practice.records.empty.title")
                                    .dsType(DS.Font.serifTitle)
                                    .fontWeight(.semibold)
                                Text("practice.records.empty.subtitle")
                                    .dsType(DS.Font.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(DS.Spacing.xl)
                        }
                    } else {
                        statsSection
                        recordsList
                    }
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.top, DS.Spacing.lg)
            }
            .navigationTitle("practice.records.title")
            .toolbar {
                if !store.records.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("practice.records.clear.all") {
                            deleteContext = .clearAll
                            showDeleteConfirmation = true
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .confirmationDialog(
                deleteContext?.titleKey ?? "practice.records.clear.confirm.title",
                isPresented: $showDeleteConfirmation
            ) {
                if let context = deleteContext {
                    Button(context.actionLabelKey, role: .destructive) {
                        handleDeleteConfirmation(for: context)
                    }
                }
                Button("cancel", role: .cancel) {
                    showDeleteConfirmation = false
                    deleteContext = nil
                }
            } message: {
                if let context = deleteContext {
                    Text(context.messageKey)
                }
            }
        }
    }

    private var statsSection: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                DSSectionHeader(titleKey: "practice.records.stats.title", subtitleKey: "practice.records.stats.subtitle", accentUnderline: true)

                let stats = store.getStatistics()
                HStack(spacing: DS.Spacing.xl) {
                    DSStatItem(
                        icon: "doc.text",
                        label: "總記錄",
                        value: "\(stats.totalRecords)"
                    )
                    DSStatItem(
                        icon: "chart.line.uptrend.xyaxis",
                        label: "平均分數",
                        value: String(format: "%.1f", stats.averageScore)
                    )
                    DSStatItem(
                        icon: "exclamationmark.triangle",
                        label: "總錯誤數",
                        value: "\(stats.totalErrors)"
                    )
                }
                .padding(.top, DS.Spacing.xs)
            }
        }
    }

    private var recordsList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            DSSectionHeader(titleKey: "practice.records.list.title", subtitleKey: "practice.records.list.subtitle", accentUnderline: true)

            LazyVStack(spacing: DS.Spacing.md) {
                ForEach(store.records.sorted { $0.createdAt > $1.createdAt }) { record in
                    PracticeRecordCard(record: record) {
                        deleteContext = .single(record)
                        showDeleteConfirmation = true
                    }
                }
            }
        }
    }

    private func handleDeleteConfirmation(for context: DeleteContext) {
        switch context {
        case .single(let record):
            store.remove(record.id)
        case .clearAll:
            store.clearAll()
        }
        showDeleteConfirmation = false
        deleteContext = nil
    }
}

#Preview {
    PracticeRecordsListView()
        .environmentObject(PracticeRecordsStore())
}
