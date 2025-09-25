import SwiftUI

struct HintRow: View {
    var hint: BankHint
    var showCategory: Bool = true
    var isSaved: Bool = false
    var onTapSave: ((BankHint) -> Void)? = nil

    var body: some View {
        HStack(alignment: .center, spacing: DS.Spacing.xs2) {
            if showCategory {
                DSTagLabel(titleKey: hint.category.displayName, color: hint.category.color)
            }
            Text(hint.text)
                .dsType(DS.Font.body)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            if let onTapSave {
                Button {
                    onTapSave(hint)
                } label: {
                    DSQuickActionIconGlyph(
                        systemName: isSaved ? "checkmark.circle.fill" : "tray.and.arrow.down",
                        shape: .circle,
                        style: isSaved ? .filled : .outline,
                        size: 28
                    )
                }
                .buttonStyle(.plain)
                .disabled(isSaved)
                .accessibilityLabel(Text(isSaved ? "a11y.hint.saved" : "a11y.hint.save"))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isSaved)
    }
}

struct HintListSection: View {
    var title: LocalizedStringKey = "hints.title"
    var hints: [BankHint]
    @Binding var isExpanded: Bool
    var collapsible: Bool = true
    var showCategory: Bool = true

    var savedPredicate: ((BankHint) -> Bool)? = nil
    var onTapSave: ((BankHint) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            if hints.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(DS.Palette.primary)
                    Text(title).dsType(DS.Font.caption).foregroundStyle(.secondary)
                    CountBubble(count: 0)
                    Spacer(minLength: 0)
                }
                Text("hints.empty")
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            } else if collapsible {
                DisclosureGroup(isExpanded: $isExpanded) {
                    list
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill").foregroundStyle(DS.Palette.primary)
                        Text(title).dsType(DS.Font.caption).foregroundStyle(.secondary)
                        CountBubble(count: hints.count)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(DS.Palette.primary)
                    Text(title).dsType(DS.Font.caption).foregroundStyle(.secondary)
                    CountBubble(count: hints.count)
                    Spacer(minLength: 0)
                }
                list
            }
        }
        .padding(DS.Spacing.md)
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Brand.scheme.babyBlue.opacity(DS.Opacity.strong), lineWidth: DS.BorderWidth.thin)
        )
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(hints.indices, id: \.self) { i in
                let hint = hints[i]
                HintRow(
                    hint: hint,
                    showCategory: showCategory,
                    isSaved: savedPredicate?(hint) ?? false,
                    onTapSave: onTapSave
                )
            }
        }
        .padding(.vertical, 4)
        .padding(.leading, 8)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(DS.Brand.scheme.babyBlue.opacity(0.25))
                .frame(width: max(DS.Metrics.hairline * 2, 1))
                .padding(.vertical, 6)
        }
    }
}

private struct CountBubble: View {
    let count: Int
    var body: some View {
        Text("\(count)")
            .dsType(DS.Font.caption)
            .padding(.vertical, 2)
            .padding(.horizontal, 6)
            .background(Capsule().fill(DS.Brand.scheme.babyBlue.opacity(0.08)))
            .overlay(Capsule().stroke(DS.Brand.scheme.babyBlue.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.thin))
    }
}
