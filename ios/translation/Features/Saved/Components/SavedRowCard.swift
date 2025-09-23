import SwiftUI

// MARK: - Models

struct DecodedRecord: Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let rawJSON: String
    let stash: SavedStash
    let source: SavedSource
    let correction: ErrorSavePayload?
    let research: ResearchSavePayload?
    let display: DecodedRecordDisplay
}

struct DecodedRecordDisplay: Equatable {
    let summary: String
    let explanation: String?
    let zhLine: String?
    let originalLine: String?
    let correctedLine: String?
    let contextTitle: String?
    let context: String?
    let hintBefore: String?
    let hintAfter: String?
}

// MARK: - Row Card Component

struct SavedErrorRowCard: View {
    let row: DecodedRecord
    let expanded: Bool
    let onToggle: () -> Void
    let onCopy: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var didCopy = false
    @State private var showDeleteConfirm = false
    @Environment(\.locale) private var locale

    var body: some View {
        DSCard(fill: DS.Palette.surface) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    summaryContent
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .foregroundStyle(.tertiary)
                        .dsAnimation(DS.AnimationToken.subtle, value: expanded)
                }
                .contentShape(Rectangle())
                .onTapGesture { onToggle() }

                if expanded {
                    expandedContent
                }
            }
        }
    }

    private var summaryContent: some View {
        Group {
            switch row.source {
            case .correction:
                if let payload = row.correction {
                    TagLabel(text: payload.error.type.displayName, color: payload.error.type.color)
                    sourceBadge(text: "saved.source.correction", color: DS.Brand.scheme.monument)
                    Text(row.display.summary)
                        .dsType(DS.Font.body)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                } else {
                    parseErrorText
                }
            case .research:
                if let payload = row.research {
                    TagLabel(text: payload.type.displayName, color: payload.type.color)
                    sourceBadge(text: "saved.source.research", color: DS.Brand.scheme.provence)
                    Text(row.display.summary)
                        .dsType(DS.Font.body)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                } else {
                    parseErrorText
                }
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        switch row.source {
        case .correction:
            if let payload = row.correction {
                correctionDetail(payload)
            } else {
                rawJSONView
            }
        case .research:
            if let payload = row.research {
                researchDetail(payload)
            } else {
                rawJSONView
            }
        }
    }

    private func correctionDetail(_ payload: ErrorSavePayload) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let explanation = row.display.explanation, !explanation.isEmpty {
                Text(explanation)
                    .dsType(DS.Font.body)
                    .foregroundStyle(.secondary)
            }
            if let suggestion = payload.error.suggestion, !suggestion.isEmpty {
                SuggestionChip(text: suggestion, color: payload.error.type.color)
            }
            Group {
                if let zhLine = row.display.zhLine {
                    Text(zhLine)
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)
                }
                if let originalLine = row.display.originalLine {
                    Text(originalLine)
                        .dsType(DS.Font.body)
                }
                if let correctedLine = row.display.correctedLine {
                    Text(correctedLine)
                        .dsType(DS.Font.body)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            footerActions
        }
    }

    private func researchDetail(_ payload: ResearchSavePayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let explanation = row.display.explanation {
                Text(explanation)
                    .dsType(DS.Font.body, lineSpacing: 6)
                    .foregroundStyle(.secondary)
            }

            if let context = row.display.context {
                VStack(alignment: .leading, spacing: 6) {
                    if let contextTitle = row.display.contextTitle {
                        Text(contextTitle)
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(context)
                        .dsType(DS.Font.body)
                }
            }

            footerActions
        }
    }

    private var footerActions: some View {
        DSFooterActionBar {
            HStack(spacing: DS.Spacing.sm2) {
                Button {
                    onCopy()
                    DSMotion.run(DS.AnimationToken.subtle) { didCopy = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        didCopy = false
                    }
                } label: {
                    if didCopy {
                        Label(String(localized: "action.copied", locale: locale), systemImage: "checkmark")
                    } else {
                        Label(String(localized: "action.copy", locale: locale), systemImage: "doc.on.doc")
                    }
                }
                .buttonStyle(DSButton(style: .secondary, size: .compact))

                Button {
                    onEdit()
                } label: {
                    Label(String(localized: "action.edit", locale: locale), systemImage: "square.and.pencil")
                }
                .buttonStyle(DSButton(style: .secondary, size: .compact))

                Spacer(minLength: 0)

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label(String(localized: "action.delete", locale: locale), systemImage: "trash")
                }
                .buttonStyle(DSButton(style: .secondary, size: .compact))
                .confirmationDialog(String(localized: "saved.delete.confirm", locale: locale), isPresented: $showDeleteConfirm, actions: {
                    Button(String(localized: "action.delete", locale: locale), role: .destructive) { onDelete() }
                })
            }
        }
    }

    private var parseErrorText: some View {
        Text(String(localized: "saved.unparsable", locale: locale))
            .dsType(DS.Font.body)
            .foregroundStyle(.secondary)
    }

    private func sourceBadge(text: LocalizedStringKey, color: Color) -> some View {
        Text(text)
            .dsType(DS.Font.caption)
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.sm2)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }

    @ViewBuilder
    private var rawJSONView: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            parseErrorText
            ScrollView(.horizontal, showsIndicators: true) {
                Text(row.rawJSON)
                    .font(DS.Font.monoSmall)
                    .textSelection(.enabled)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            footerActions
        }
    }

}
