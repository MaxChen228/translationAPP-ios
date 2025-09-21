import SwiftUI

struct PracticeRecordsListView: View {
    @EnvironmentObject private var store: PracticeRecordsStore
    @Environment(\.locale) private var locale
    @State private var showDeleteConfirmation = false
    @State private var recordToDelete: PracticeRecord?

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.lg) {
                    if store.records.isEmpty {
                        DSOutlineCard {
                            VStack(spacing: DS.Spacing.md) {
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
                            .padding(DS.Spacing.lg)
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
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                DSSectionHeader(titleKey: "practice.records.stats.title", subtitleKey: "practice.records.stats.subtitle", accentUnderline: true)

                let stats = store.getStatistics()
                HStack(spacing: DS.Spacing.lg) {
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
            }
        }
    }

    private var recordsList: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DSSectionHeader(titleKey: "practice.records.list.title", subtitleKey: "practice.records.list.subtitle", accentUnderline: true)

            ForEach(store.records.sorted { $0.createdAt > $1.createdAt }) { record in
                PracticeRecordCard(record: record) {
                    recordToDelete = record
                    showDeleteConfirmation = true
                }
            }
        }
    }
}

private struct PracticeRecordCard: View {
    let record: PracticeRecord
    let onDelete: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Header with date and score
                HStack {
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(record.createdAt, style: .date)
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                        Text(record.createdAt, style: .time)
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: DS.Spacing.sm) {
                        DSScoreBadge(score: record.score)
                        Text("\(record.errors.count)")
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "exclamationmark.triangle")
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                DSSeparator(color: DS.Palette.border.opacity(DS.Opacity.hairline))

                // Chinese text section
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("中文原文")
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)
                    Text(record.chineseText)
                        .dsType(DS.Font.serifBody, lineSpacing: 6, tracking: 0.1)
                        .lineLimit(2)
                }

                // English text section
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("英文翻譯")
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)
                    Text(record.englishInput)
                        .dsType(DS.Font.body)
                        .lineLimit(2)
                }

                // Bank book name if available
                if let bankBookName = record.bankBookName {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "book")
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                        Text(bankBookName)
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .contextMenu {
            Button("delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

#Preview {
    PracticeRecordsListView()
        .environmentObject(PracticeRecordsStore())
}