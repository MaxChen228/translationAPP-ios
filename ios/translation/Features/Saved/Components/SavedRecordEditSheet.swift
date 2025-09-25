import SwiftUI

struct SavedRecordEditSheet: View {
    let record: DecodedRecord
    @Binding var text: String
    let onSave: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            ScrollView {
                DSEditFormCard(
                    titleKey: "saved.edit.title",
                    subtitleKey: "saved.edit.description",
                    contentSpacing: DS.Spacing.md
                ) {
                    DSTextArea(
                        text: $text,
                        minHeight: 240,
                        placeholder: "",
                        disableAutocorrection: true
                    )
                    .font(DS.Font.monoSmall)
                } footer: {
                    HStack(spacing: DS.Spacing.md) {
                        Button(String(localized: "action.cancel", locale: locale)) {
                            onCancel()
                            dismiss()
                        }
                        .buttonStyle(DSButton(style: .secondary, size: .full))

                        Button(String(localized: "action.save", locale: locale)) {
                            onSave()
                            dismiss()
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
    }
}
