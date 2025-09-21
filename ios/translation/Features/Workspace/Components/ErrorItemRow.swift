import SwiftUI

struct ErrorItemRow: View {
    var err: ErrorItem
    var selected: Bool
    var onSave: ((ErrorItem) -> Void)? = nil

    var body: some View {
        let theme = ErrorTheme.theme(for: err.type)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                TagLabel(text: err.type.displayName, color: err.type.color)
                Text(err.span)
                    .dsType(DS.Font.body)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            Text(err.explainZh)
                .dsType(DS.Font.body, lineSpacing: 4)
                .foregroundStyle(.secondary)
            if let s = err.suggestion, !s.isEmpty {
                HStack(spacing: 8) {
                    Text("error.suggestion")
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)
                    SuggestionChip(text: s, color: theme.base)
                }
            }
        }
        .padding(DS.Spacing.md2)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(selected ? theme.base.opacity(0.6) : theme.border, lineWidth: selected ? 1.2 : 0.8)
                .overlay(
                    Rectangle()
                        .fill(theme.base)
                        .frame(width: DS.IconSize.dividerThin)
                        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                        .padding(.vertical, 6), alignment: .leading
                )
        }
        .overlay(alignment: .bottomLeading) { EmptyView() } // keep overlay chain simple
        .modifier(SaveActionBar(onSave: onSave, err: err))
    }
}

// 將儲存動作列放在內容下方，避免覆蓋文字/建議
private struct SaveActionBar: ViewModifier {
    let onSave: ((ErrorItem) -> Void)?
    let err: ErrorItem
    @State private var didSave = false
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
            if let onSave {
                VStack(spacing: 6) {
                    DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(0.35))
                    HStack {
                        Spacer()
                        Button {
                            onSave(err)
                            DSMotion.run(DS.AnimationToken.subtle) { didSave = true }
                        } label: {
                            if didSave {
                                DSIconLabel(textKey: "action.saved", systemName: "checkmark.seal.fill")
                            } else {
                                DSIconLabel(textKey: "action.save", systemName: "tray.and.arrow.down")
                            }
                        }
                        .buttonStyle(DSButton(style: .secondary, size: .compact))
                        .disabled(didSave)
                    }
                }
                .padding(.top, 8)
            }
        }
    }
}
