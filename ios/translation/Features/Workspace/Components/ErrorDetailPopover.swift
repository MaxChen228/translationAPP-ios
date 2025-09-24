import SwiftUI

struct ErrorDetailPopover: View {
    var err: ErrorItem
    var onApply: (() -> Void)?
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
            HStack(spacing: DS.Spacing.sm) {
                TagLabel(text: err.type.displayName, color: err.type.color)
                Text(err.span)
                    .dsType(DS.Font.bodyEmph)
            }
            Text(err.explainZh)
                .foregroundStyle(.secondary)
                .dsType(DS.Font.body)
            if let s = err.suggestion, !s.isEmpty {
                HStack(spacing: DS.Spacing.xs2) {
                    Text("error.suggestion")
                        .foregroundStyle(.secondary)
                        .dsType(DS.Font.caption)
                    SuggestionChip(text: s, color: err.type.color)
                }
                if let onApply {
                    Button {
                        onApply()
                    } label: {
                        Label(String(localized: "error.applySuggestion", locale: locale), systemImage: "arrow.right.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DSButton(style: .primary, size: .full))
                }
            }
        }
        .padding(DS.Spacing.md)
        .frame(maxWidth: DS.Metrics.popoverMaxWidth)
    }
}
