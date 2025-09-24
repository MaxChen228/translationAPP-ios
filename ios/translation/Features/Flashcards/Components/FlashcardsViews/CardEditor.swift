import SwiftUI

struct CardEditor: View {
    @Binding var draft: Flashcard?
    @Binding var errorText: String?
    @Binding var familiaritySelection: Bool?
    @Binding var llmInstruction: String
    let llmError: String?
    let isGenerating: Bool
    let onGenerate: () -> Void
    let showsFamiliaritySelector: Bool
    let onDelete: () -> Void

    var body: some View {
        DSCard(padding: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: 12) {
                Text("flashcards.editor.title").dsType(DS.Font.section)
                TextField(
                    LocalizedStringKey("flashcards.editor.front"),
                    text: Binding(
                        get: { draft?.front ?? "" },
                        set: {
                            guard var d = draft else { return }
                            d.front = $0
                            draft = d
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)

                TextField(
                    LocalizedStringKey("flashcards.editor.frontNote"),
                    text: Binding(
                        get: { draft?.frontNote ?? "" },
                        set: {
                            guard var d = draft else { return }
                            d.frontNote = $0.isEmpty ? nil : $0
                            draft = d
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)

                TextField(
                    LocalizedStringKey("flashcards.editor.back"),
                    text: Binding(
                        get: { draft?.back ?? "" },
                        set: {
                            guard var d = draft else { return }
                            d.back = $0
                            draft = d
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)

                TextField(
                    LocalizedStringKey("flashcards.editor.backNote"),
                    text: Binding(
                        get: { draft?.backNote ?? "" },
                        set: {
                            guard var d = draft else { return }
                            d.backNote = $0.isEmpty ? nil : $0
                            draft = d
                        }
                    )
                )
                .textFieldStyle(.roundedBorder)

                Button(role: .destructive) { onDelete() } label: {
                    Text("flashcards.editor.delete")
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                DSSeparator()

                VStack(alignment: .leading, spacing: 8) {
                    Text("flashcards.generator.title")
                        .dsType(DS.Font.body)
                        .foregroundStyle(.primary)
                    Text("flashcards.generator.subtitle")
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)

                    DSTextArea(
                        text: $llmInstruction,
                        minHeight: 80,
                        placeholder: String(localized: "flashcards.generator.instructionPlaceholder"),
                        disableAutocorrection: true
                    )

                    Button(action: onGenerate) {
                        HStack(spacing: DS.Spacing.sm) {
                            if isGenerating {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            }
                            Text(isGenerating ? String(localized: "flashcards.generator.loading") : String(localized: "flashcards.generator.action"))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DSButton(style: .primary, size: .full))
                    .disabled(isGenerating)

                    if let llmError {
                        Text(llmError)
                            .font(.caption)
                            .foregroundStyle(DS.Palette.danger)
                    }
                }
                .padding(.top, DS.Spacing.sm)

                if showsFamiliaritySelector {
                    DSSeparator()
                    VStack(alignment: .leading, spacing: 8) {
                        Text("flashcards.editor.familiarity").dsType(DS.Font.body).foregroundStyle(.primary)
                        Picker("flashcards.editor.familiarity", selection: familiarityBinding) {
                            Text("flashcards.editor.unfamiliar").tag(false)
                            Text("flashcards.editor.familiar").tag(true)
                        }
                        .pickerStyle(.segmented)
                        .tint(DS.Palette.primary)
                    }
                }

                if let errorText {
                    Text(errorText)
                        .foregroundStyle(DS.Palette.danger)
                        .font(.caption)
                }
            }
        }
    }
}

private extension CardEditor {
    var familiarityBinding: Binding<Bool> {
        Binding(
            get: { familiaritySelection ?? false },
            set: { familiaritySelection = $0 }
        )
    }
}
