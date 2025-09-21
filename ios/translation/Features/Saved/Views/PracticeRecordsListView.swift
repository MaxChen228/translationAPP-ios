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
                        DSCard {
                            VStack(spacing: DS.Spacing.md) {
                                Image(systemName: "doc.text")
                                    .font(.largeTitle)
                                    .foregroundStyle(.secondary)
                                Text("practice.records.empty.title")
                                    .font(.headline)
                                Text("practice.records.empty.subtitle")
                                    .font(.caption)
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
        DSCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                DSSectionHeader(titleKey: "practice.records.stats.title", subtitleKey: "practice.records.stats.subtitle", accentUnderline: true)

                let stats = store.getStatistics()
                HStack(spacing: DS.Spacing.lg) {
                    StatItem(title: "practice.records.stats.total", value: "\(stats.totalRecords)")
                    StatItem(title: "practice.records.stats.avgScore", value: String(format: "%.1f", stats.averageScore))
                    StatItem(title: "practice.records.stats.totalErrors", value: "\(stats.totalErrors)")
                }
            }
            .padding(DS.Spacing.md)
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

private struct StatItem: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
        }
    }
}

private struct PracticeRecordCard: View {
    let record: PracticeRecord
    let onDelete: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        DSCard {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(record.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(record.createdAt, style: .time)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    HStack(spacing: DS.Spacing.sm) {
                        ScoreBadge(score: record.score)
                        Text("\(record.errors.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("practice.records.card.chinese")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(record.chineseText)
                        .font(.body)
                        .lineLimit(2)
                }

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text("practice.records.card.english")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(record.englishInput)
                        .font(.body)
                        .lineLimit(2)
                }

                if let bankBookName = record.bankBookName {
                    HStack {
                        Image(systemName: "book")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(bankBookName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(DS.Spacing.md)
        }
        .contextMenu {
            Button("delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

private struct ScoreBadge: View {
    let score: Int

    private var color: Color {
        switch score {
        case 90...100: return .green
        case 80..<90: return .blue
        case 70..<80: return .orange
        case 60..<70: return .yellow
        default: return .red
        }
    }

    var body: some View {
        Text("\(score)")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    PracticeRecordsListView()
        .environmentObject(PracticeRecordsStore())
}