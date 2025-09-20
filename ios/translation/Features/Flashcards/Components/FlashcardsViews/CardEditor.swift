import SwiftUI

struct CardEditor: View {
    @Binding var draft: Flashcard?
    @Binding var errorText: String?
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

                if let errorText {
                    Text(errorText)
                        .foregroundStyle(DS.Palette.danger)
                        .font(.caption)
                }
            }
        }
    }
}
