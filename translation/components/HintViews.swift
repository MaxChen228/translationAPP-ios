import SwiftUI

struct HintRow: View {
    var hint: BankHint
    var showCategory: Bool = true

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            if showCategory {
                TagLabel(text: hint.category.displayName, color: hint.category.color)
            }
            Text(hint.text)
                .dsType(DS.Font.body)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }
}

struct HintListSection: View {
    var title: String = "提示"
    var hints: [BankHint]
    @Binding var isExpanded: Bool
    var collapsible: Bool = true
    var showCategory: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            if hints.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(DS.Palette.primary)
                    Text(title).dsType(DS.Font.caption).foregroundStyle(.secondary)
                    CountBubble(count: 0)
                    Spacer(minLength: 0)
                }
                Text("目前沒有提示")
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
                .stroke(DS.Brand.scheme.babyBlue.opacity(0.45), lineWidth: DS.BorderWidth.thin)
        )
    }

    private var list: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(hints.indices, id: \.self) { i in
                HintRow(hint: hints[i], showCategory: showCategory)
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

struct TagLabel: View {
    var text: String
    var color: Color
    var body: some View {
        Text(text)
            .dsType(DS.Font.caption)
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .background(Capsule().fill(color.opacity(0.12)))
            .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: DS.BorderWidth.thin))
            .foregroundStyle(color)
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
            .overlay(Capsule().stroke(DS.Brand.scheme.babyBlue.opacity(0.35), lineWidth: DS.BorderWidth.thin))
    }
}
