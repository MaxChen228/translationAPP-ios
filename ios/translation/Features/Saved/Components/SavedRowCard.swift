import SwiftUI

// MARK: - Models

struct DecodedRecord: Identifiable, Equatable {
    let id: UUID
    let createdAt: Date
    let rawJSON: String
    let stash: SavedStash
    let payload: KnowledgeSavePayload?
    let display: DecodedRecordDisplay
}

struct DecodedRecordDisplay: Equatable {
    let title: String
    let explanation: String
    let correctExample: String
    let note: String?
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
        VStack(alignment: .leading, spacing: 4) {
            if let payload = row.payload {
                Text(payload.title)
                    .dsType(DS.Font.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let note = payload.note, !note.isEmpty {
                    Text(note)
                        .dsType(DS.Font.caption)
                        .foregroundStyle(DS.Brand.scheme.classicBlue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(DS.Brand.scheme.classicBlue.opacity(0.1))
                        .clipShape(Capsule())
                }
            } else {
                parseErrorText
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        if let payload = row.payload {
            VStack(alignment: .leading, spacing: 12) {
                if !row.display.explanation.isEmpty {
                    Text(row.display.explanation)
                        .dsType(DS.Font.body, lineSpacing: 6)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "saved.correctExample", locale: locale))
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)
                    Text(row.display.correctExample)
                        .dsType(DS.Font.body)
                        .foregroundStyle(.primary)
                }

                if let note = row.display.note, !note.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "saved.note", locale: locale))
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                        Text(note)
                            .dsType(DS.Font.body)
                    }
                }

                footerActions
            }
        } else {
            rawJSONView
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
                    let labelKey: LocalizedStringKey = didCopy ? "action.copied" : "action.copy"
                    let systemImage = didCopy ? "checkmark" : "doc.on.doc"
                    Label(labelKey, systemImage: systemImage)
                        .labelStyle(.iconOnly)
                        .accessibilityLabel(Text(labelKey))
                }
                .buttonStyle(DSButton(style: .secondary, size: .compact))

                Button {
                    onEdit()
                } label: {
                    Label(String(localized: "action.edit", locale: locale), systemImage: "square.and.pencil")
                        .labelStyle(.iconOnly)
                        .accessibilityLabel(Text(String(localized: "action.edit", locale: locale)))
                }
                .buttonStyle(DSButton(style: .secondary, size: .compact))

                Spacer(minLength: 0)

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    Label(String(localized: "action.delete", locale: locale), systemImage: "trash")
                        .labelStyle(.iconOnly)
                        .accessibilityLabel(Text(String(localized: "action.delete", locale: locale)))
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
            .dsType(DS.Font.caption)
            .foregroundStyle(.secondary)
    }

    private var rawJSONView: some View {
        Text(row.rawJSON)
            .dsType(DS.Font.caption)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
