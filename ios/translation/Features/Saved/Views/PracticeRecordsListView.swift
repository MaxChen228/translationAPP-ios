import SwiftUI

struct PracticeRecordsListView: View {
    @EnvironmentObject private var store: PracticeRecordsStore
    @Environment(\.locale) private var locale
    @State private var showDeleteConfirmation = false
    @State private var recordToDelete: PracticeRecord?

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
                            showDeleteConfirmation = true
                        }
                        .foregroundStyle(.red)
                    }
                }
            }
            .confirmationDialog(
                "practice.records.clear.confirm.title",
                isPresented: $showDeleteConfirmation
            ) {
                Button("practice.records.clear.confirm.action", role: .destructive) {
                    store.clearAll()
                }
                Button("cancel", role: .cancel) { }
            } message: {
                Text("practice.records.clear.confirm.message")
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
                        recordToDelete = record
                        showDeleteConfirmation = true
                    }
                }
            }
        }
    }
}

#Preview {
    PracticeRecordsListView()
        .environmentObject(PracticeRecordsStore())
}