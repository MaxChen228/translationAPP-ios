import SwiftUI

struct PracticeRecordCard: View {
    let record: PracticeRecord
    var onDelete: (() -> Void)? = nil

    var body: some View {
        DSOutlineCard {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                header
                DSSeparator(color: DS.Palette.border.opacity(0.08))
                contentSection(title: "中文原文", text: record.chineseText, isSerif: true)
                contentSection(title: "英文翻譯", text: record.englishInput, isSerif: false)

                if let bankBookName = record.bankBookName {
                    HStack(spacing: DS.Spacing.xs2) {
                        Image(systemName: "book")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(bankBookName)
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(DS.Spacing.md)
        }
        .contextMenu {
            if let onDelete {
                Button("delete", role: .destructive, action: onDelete)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
                Text(record.createdAt, style: .date)
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
                Text(record.createdAt, style: .time)
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            HStack(spacing: DS.Spacing.sm) {
                DSScoreBadge(score: record.score, style: .compact)
                if record.errors.count > 0 {
                    HStack(spacing: DS.Spacing.xs2) {
                        Text("\\(record.errors.count)")
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func contentSection(title: String, text: String, isSerif: Bool) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
            Text(title)
                .dsType(DS.Font.caption)
                .foregroundStyle(.tertiary)
            Text(text)
                .dsType(isSerif ? DS.Font.serifBody : DS.Font.body, lineSpacing: isSerif ? 4 : 2, tracking: isSerif ? 0.05 : 0)
                .lineLimit(2)
                .foregroundStyle(isSerif ? .primary : .secondary)
        }
    }

}
