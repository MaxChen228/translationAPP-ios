import SwiftUI

struct DSEditFormCard<Content: View, Footer: View>: View {
    private let titleKey: LocalizedStringKey
    private let subtitleKey: LocalizedStringKey?
    private let contentSpacing: CGFloat
    private let footerSpacing: CGFloat
    private let contentBuilder: () -> Content
    private let footerBuilder: () -> Footer

    init(
        titleKey: LocalizedStringKey,
        subtitleKey: LocalizedStringKey? = nil,
        contentSpacing: CGFloat = DS.Spacing.md,
        footerSpacing: CGFloat = DS.Spacing.sm,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.titleKey = titleKey
        self.subtitleKey = subtitleKey
        self.contentSpacing = contentSpacing
        self.footerSpacing = footerSpacing
        self.contentBuilder = content
        self.footerBuilder = footer
    }

    init(
        titleKey: LocalizedStringKey,
        subtitleKey: LocalizedStringKey? = nil,
        contentSpacing: CGFloat = DS.Spacing.md,
        @ViewBuilder content: @escaping () -> Content
    ) where Footer == EmptyView {
        self.init(
            titleKey: titleKey,
            subtitleKey: subtitleKey,
            contentSpacing: contentSpacing,
            footerSpacing: DS.Spacing.sm,
            content: content,
            footer: { EmptyView() }
        )
    }

    var body: some View {
        DSCard(padding: DS.Spacing.lg) {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
                    Text(titleKey)
                        .dsType(DS.Font.section)
                    if let subtitleKey {
                        Text(subtitleKey)
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: contentSpacing) {
                    contentBuilder()
                }

                if hasFooter {
                    DSSeparator()
                    VStack(alignment: .leading, spacing: footerSpacing) {
                        footerBuilder()
                    }
                }
            }
        }
    }

    private var hasFooter: Bool {
        Footer.self != EmptyView.self
    }
}
