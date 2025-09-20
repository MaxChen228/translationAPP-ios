import SwiftUI

struct FlashcardsMarkdownText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    private func preprocess(_ markdown: String) -> String {
        markdown.split(separator: "\n", omittingEmptySubsequences: false).map { line in
            let string = String(line)
            let trimmed = string.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                return "• " + trimmed.dropFirst(2)
            }
            if trimmed.hasPrefix("#") {
                let dropped = trimmed.drop(while: { $0 == "#" || $0 == " " })
                return String(dropped)
            }
            return string
        }.joined(separator: "\n")
    }

    var body: some View {
        let processed = preprocess(text)
        Group {
            if let attributed = try? AttributedString(
                markdown: processed,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnlyPreservingWhitespace,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )
            ) {
                Text(attributed)
            } else {
                Text(processed)
            }
        }
        .foregroundStyle(.primary)
        .textSelection(.enabled)
    }
}

struct FlashcardsNoteText: View {
    let text: String

    var body: some View {
        Text(text)
            .dsType(DS.Font.caption)
            .foregroundStyle(.secondary)
    }
}
