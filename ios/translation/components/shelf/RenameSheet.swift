import SwiftUI

struct RenameSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @State private var text: String
    let onDone: (String) -> Void

    init(title: String = "重新命名", name: String, onDone: @escaping (String) -> Void) {
        self.title = title
        self._text = State(initialValue: name)
        self.onDone = onDone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).dsType(DS.Font.section)
            TextField("名稱", text: $text)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("取消") { dismiss() }
                Button("完成") {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { onDone(trimmed) }
                    dismiss()
                }
                .buttonStyle(DSPrimaryButton())
                .frame(width: 120)
            }
        }
        .padding(16)
        .background(DS.Palette.background)
    }
}

