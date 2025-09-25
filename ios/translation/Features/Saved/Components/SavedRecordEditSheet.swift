import SwiftUI

struct SavedRecordEditSheet: View {
    let record: DecodedRecord
    @Binding var text: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    @State private var editMode: EditMode = .form
    @State private var titleText: String = ""
    @State private var explanationText: String = ""
    @State private var correctExampleText: String = ""
    @State private var noteText: String = ""
    @State private var payloadID: UUID?
    @State private var savedAt: Date = Date()
    @State private var sourceHintID: UUID?
    @State private var validationMessage: String?
    @State private var didInitialize = false

    var body: some View {
        NavigationStack {
            ScrollView {
                DSEditFormCard(
                    titleKey: "saved.edit.title",
                    subtitleKey: "saved.edit.description",
                    contentSpacing: DS.Spacing.md
                ) {
                    Picker("saved.edit.mode.picker", selection: $editMode) {
                        ForEach(EditMode.allCases) { mode in
                            Text(mode.labelKey)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .tint(DS.Palette.primary)
                    .labelsHidden()
                    .onChange(of: editMode) { _, newValue in
                        switch newValue {
                        case .form:
                            if !applyJSONToForm() {
                                validationMessage = String(localized: "saved.edit.invalid", locale: locale)
                                editMode = .json
                            } else {
                                validationMessage = nil
                            }
                        case .json:
                            if let encoded = encodeFormToJSON() {
                                text = encoded
                            }
                            validationMessage = nil
                        }
                    }

                    if editMode == .form {
                        formFields
                    } else {
                        jsonEditor
                    }

                    if let validationMessage {
                        Text(validationMessage)
                            .foregroundStyle(DS.Palette.danger)
                            .font(.caption)
                    }
                } footer: {
                    HStack(spacing: DS.Spacing.md) {
                        Button(String(localized: "action.cancel", locale: locale)) {
                            onCancel()
                            dismiss()
                        }
                        .buttonStyle(DSButton(style: .secondary, size: .full))

                        Button(String(localized: "action.save", locale: locale)) {
                            handleSave()
                        }
                        .buttonStyle(DSButton(style: .primary, size: .full))
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.lg)
            .background(DS.Palette.background)
            .navigationTitle(Text("saved.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { initializeIfNeeded() }
    }
}

// MARK: - Private Helpers

private extension SavedRecordEditSheet {
    enum EditMode: String, CaseIterable, Identifiable {
        case form
        case json

        var id: String { rawValue }

        var labelKey: LocalizedStringKey {
            switch self {
            case .form: return "saved.edit.mode.form"
            case .json: return "saved.edit.mode.json"
            }
        }
    }

    var formFields: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
            TextField(String(localized: "saved.edit.field.title", locale: locale), text: $titleText)
                .textFieldStyle(.roundedBorder)

            DSTextArea(
                text: $explanationText,
                minHeight: 100,
                placeholder: String(localized: "saved.edit.field.explanation", locale: locale),
                disableAutocorrection: false
            )

            DSTextArea(
                text: $correctExampleText,
                minHeight: 100,
                placeholder: String(localized: "saved.edit.field.correctExample", locale: locale),
                disableAutocorrection: false
            )

            DSTextArea(
                text: $noteText,
                minHeight: 80,
                placeholder: String(localized: "saved.edit.field.note", locale: locale),
                disableAutocorrection: false
            )

            metadataSection
        }
    }

    var metadataSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
            DSSeparator()
            Text("saved.edit.metadata.title")
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)

            if let payloadID {
                metadataRow(
                    labelKey: "saved.edit.metadata.id",
                    value: payloadID.uuidString,
                    systemImage: "number"
                )
            }

            metadataRow(
                labelKey: "saved.edit.metadata.savedAt",
                value: savedAt.formatted(date: .abbreviated, time: .shortened),
                systemImage: "calendar"
            )

            if let sourceHintID {
                metadataRow(
                    labelKey: "saved.edit.metadata.sourceHint",
                    value: sourceHintID.uuidString,
                    systemImage: "tag"
                )
            }
        }
    }

    func metadataRow(labelKey: LocalizedStringKey, value: String, systemImage: String) -> some View {
        HStack(spacing: DS.Spacing.xs2) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(labelKey)
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
        }
    }

    var jsonEditor: some View {
        DSTextArea(
            text: $text,
            minHeight: 240,
            placeholder: String(localized: "saved.edit.json.placeholder", locale: locale),
            disableAutocorrection: true
        )
        .font(DS.Font.monoSmall)
    }

    func initializeIfNeeded() {
        guard !didInitialize else { return }
        didInitialize = true
        if let payload = record.payload ?? decodePayload(from: text) {
            applyPayload(payload)
            validationMessage = nil
            editMode = .form
            if let encoded = try? encodePayload(payload) {
                text = encoded
            }
        } else {
            editMode = .json
            validationMessage = String(localized: "saved.edit.invalid", locale: locale)
        }
    }

    func applyPayload(_ payload: KnowledgeSavePayload) {
        payloadID = payload.id
        savedAt = payload.savedAt
        sourceHintID = payload.sourceHintID
        titleText = payload.title
        explanationText = payload.explanation
        correctExampleText = payload.correctExample
        noteText = payload.note ?? ""
    }

    func applyJSONToForm() -> Bool {
        guard let payload = decodePayload(from: text) else { return false }
        applyPayload(payload)
        return true
    }

    func decodePayload(from json: String) -> KnowledgeSavePayload? {
        guard let data = json.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(KnowledgeSavePayload.self, from: data)
    }

    func encodeFormToJSON() -> String? {
        let trimmedTitle = titleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNote = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
        let payload = KnowledgeSavePayload(
            id: payloadID ?? record.payload?.id ?? UUID(),
            savedAt: savedAt,
            title: trimmedTitle,
            explanation: explanationText,
            correctExample: correctExampleText,
            note: trimmedNote.isEmpty ? nil : trimmedNote,
            sourceHintID: sourceHintID ?? record.payload?.sourceHintID
        )
        return try? encodePayload(payload)
    }

    func encodePayload(_ payload: KnowledgeSavePayload) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(payload)
        guard let json = String(data: data, encoding: .utf8) else { throw EncodingError.invalidValue(payload, .init(codingPath: [], debugDescription: "Invalid UTF-8")) }
        return json
    }

    func handleSave() {
        switch editMode {
        case .form:
            guard let json = encodeFormToJSON() else {
                validationMessage = String(localized: "saved.edit.encodeFailed", locale: locale)
                return
            }
            text = json
            validationMessage = nil
            onSave()
            dismiss()
        case .json:
            guard decodePayload(from: text) != nil else {
                validationMessage = String(localized: "saved.edit.invalid", locale: locale)
                return
            }
            validationMessage = nil
            onSave()
            dismiss()
        }
    }
}
