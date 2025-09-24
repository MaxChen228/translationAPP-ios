import SwiftUI

struct RenameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    let titleKey: LocalizedStringKey
    @State private var text: String
    let onDone: (String) -> Void

    init(titleKey: LocalizedStringKey = "action.rename", name: String, onDone: @escaping (String) -> Void) {
        self.titleKey = titleKey
        self._text = State(initialValue: name)
        self.onDone = onDone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
            Text(titleKey).dsType(DS.Font.section)
            TextField(String(localized: "field.name", locale: locale), text: $text)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button(String(localized: "action.cancel", locale: locale)) { dismiss() }
                Button(String(localized: "action.done", locale: locale)) {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { onDone(trimmed) }
                    dismiss()
                }
                .buttonStyle(DSButton(style: .primary, size: .full))
                .frame(width: DS.ButtonSize.standard)
            }
        }
        .padding(DS.Spacing.md)
        .background(DS.Palette.background)
    }
}
