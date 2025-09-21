import SwiftUI

struct SaveDeckNameSheet: View {
    enum Action { case cancel, save(String) }
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var text: String
    let count: Int
    let isSaving: Bool
    let onAction: (Action) -> Void

    init(name: String, count: Int, isSaving: Bool, onAction: @escaping (Action) -> Void) {
        self._text = State(initialValue: name)
        self.count = count
        self.isSaving = isSaving
        self.onAction = onAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "saved.saveDeck", locale: locale))
                .dsType(DS.Font.section)
            Text(String(localized: "saved.saveDeck.prompt", locale: locale) + " \(count)")
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)

            TextField(String(localized: "saved.deckName.placeholder", locale: locale), text: $text)
                .textFieldStyle(.roundedBorder)
                .disabled(isSaving)

            HStack {
                Button(role: .cancel) {
                    onAction(.cancel)
                    dismiss()
                } label: { Text("action.cancel") }
                .buttonStyle(DSButton(style: .secondary, size: .compact))
                .disabled(isSaving)

                Spacer()

                Button {
                    onAction(.save(text))
                    dismiss()
                } label: {
                    if isSaving {
                        ProgressView()
                    } else {
                        Text("action.save")
                    }
                }
                .buttonStyle(DSButton(style: .primary, size: .compact))
                .disabled(isSaving)
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
    }
}