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
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                Text(String(localized: "saved.edit.description", locale: locale))
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $text)
                    .font(DS.Font.monoSmall)
                    .frame(minHeight: 240)
                    .overlay(
                        RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                            .stroke(DS.Palette.border.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.hairline)
                    )
                    .background(DS.Palette.surface)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .navigationTitle(Text("saved.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel", locale: locale)) {
                        onCancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.save", locale: locale)) {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}
