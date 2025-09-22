import SwiftUI

struct PracticeRecordCard: View {
    let record: PracticeRecord
    var onDelete: (() -> Void)? = nil

    @State private var isExpanded = false

    var body: some View {
        DSOutlineCard(padding: DS.Spacing.md) {
            HStack(alignment: .top, spacing: DS.Spacing.md) {
                timelineIndicator

                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    header

                    if isExpanded {
                        expandedContent
                    } else {
                        collapsedPreview
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.88)) {
                isExpanded.toggle()
            }
        }
        .contextMenu {
            if let onDelete {
                Button("delete", role: .destructive, action: onDelete)
            }
        }
    }

    private var timelineIndicator: some View {
        VStack(spacing: DS.Spacing.xs) {
            Circle()
                .fill(DS.Palette.primary)
                .frame(width: 10, height: 10)

            Rectangle()
                .fill(DS.Palette.primary.opacity(0.15))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
            Spacer(minLength: 0)
        }
        .frame(width: 14)
        .padding(.top, DS.Spacing.xs)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
                HStack(spacing: DS.Spacing.xs2) {
                    Text(record.createdAt, style: .date)
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)
                    Text(record.createdAt, style: .time)
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.tertiary)
                }

                metadataRow
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DS.Spacing.xs2) {
                DSScoreBadge(score: record.score, style: .compact)

                if record.errors.count > 0 {
                    HStack(spacing: DS.Spacing.xs2) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundStyle(DS.Palette.warning)
                        Text("\(record.errors.count)")
                            .dsType(DS.Font.caption)
                            .foregroundStyle(DS.Palette.warning)
                    }
                }

                if record.attemptCount > 1 {
                    Text("×\(record.attemptCount)")
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, DS.Spacing.xs)
        }
    }

    private var metadataRow: some View {
        HStack(spacing: DS.Spacing.xs) {
            if let bank = record.bankBookName {
                tagView(icon: "book", text: bank)
            }

            if let tag = record.practiceTag {
                tagView(icon: "tag", text: tag)
            }
        }
    }

    private var collapsedPreview: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
            Text(record.chineseText)
                .dsType(DS.Font.serifBody)
                .lineLimit(2)
                .foregroundStyle(.primary)

            Text(record.englishInput)
                .dsType(DS.Font.body)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            DSSeparator(color: DS.Palette.border.opacity(0.08))

            detailSection(
                titleKey: "practice.records.card.chinese",
                text: record.chineseText,
                style: .serif
            )

            detailSection(
                titleKey: "practice.records.card.english",
                text: record.englishInput,
                style: .plain
            )

            detailSection(
                titleKey: "practice.records.card.corrected",
                text: record.correctedText,
                style: .plain
            )

            if let suggestion = record.teacherSuggestion, !suggestion.isEmpty {
                detailSection(
                    titleKey: "practice.records.card.suggestion",
                    text: suggestion,
                    style: .plain
                )
            }

            if !record.errors.isEmpty {
                VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
                    Text("practice.records.card.errors")
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.tertiary)

                    ForEach(uniqueErrorTypes, id: \.id) { type in
                        HStack(spacing: DS.Spacing.xs2) {
                            Circle()
                                .fill(type.color.opacity(0.7))
                                .frame(width: 6, height: 6)
                            Text(type.displayName)
                                .dsType(DS.Font.caption)
                                .foregroundStyle(type.color)
                        }
                    }
                }
            }
        }
    }

    private func tagView(icon: String, text: String) -> some View {
        Label(text, systemImage: icon)
            .labelStyle(.titleAndIcon)
            .dsType(DS.Font.caption)
            .foregroundStyle(.tertiary)
            .lineLimit(1)
    }

    private enum DetailTextStyle {
        case serif
        case plain

        var font: SwiftUI.Font {
            switch self {
            case .serif: return DS.Font.serifBody
            case .plain: return DS.Font.body
            }
        }

        var lineSpacing: CGFloat {
            switch self {
            case .serif: return 4
            case .plain: return 2
            }
        }
    }

    private func detailSection(titleKey: LocalizedStringKey, text: String, style: DetailTextStyle) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
            Text(titleKey)
                .dsType(DS.Font.caption)
                .foregroundStyle(.tertiary)

            Text(text)
                .dsType(style.font, lineSpacing: style.lineSpacing)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
        }
    }

    private var uniqueErrorTypes: [ErrorType] {
        var seen: Set<ErrorType> = []
        var result: [ErrorType] = []
        for error in record.errors {
            if !seen.contains(error.type) {
                seen.insert(error.type)
                result.append(error.type)
            }
        }
        return result
    }
}
