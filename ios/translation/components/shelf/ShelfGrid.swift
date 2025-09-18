import SwiftUI

struct ShelfGrid<Content: View>: View {
    var titleKey: LocalizedStringKey? = nil
    var subtitleKey: LocalizedStringKey? = nil
    var columns: [GridItem]
    @ViewBuilder var content: () -> Content

    init(
        titleKey: LocalizedStringKey? = nil,
        subtitleKey: LocalizedStringKey? = nil,
        columns: [GridItem] = [GridItem(.adaptive(minimum: 160), spacing: DS.Spacing.sm2)],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.columns = columns
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
            if let t = titleKey, let s = subtitleKey {
                DSSectionHeader(titleKey: t, subtitleKey: s, accentUnderline: true)
            } else if let t = titleKey {
                DSSectionHeader(titleKey: t, subtitleKey: nil, accentUnderline: true)
            } else if let s = subtitleKey {
                DSSectionHeader(titleText: Text(""), subtitleText: Text(s), accentUnderline: true)
            }
            LazyVGrid(columns: columns, spacing: DS.Spacing.sm2) {
                content()
            }
        }
    }
}
