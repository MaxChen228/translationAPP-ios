import SwiftUI

struct ChatBubble: View {
    var message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top) {
            if isUser {
                Spacer(minLength: 24)
                ChatMessageContainer(style: .user) {
                    messageContent(style: .user)
                }
            } else {
                ChatMessageContainer(style: .assistant) {
                    messageContent(style: .assistant)
                }
                Spacer(minLength: 24)
            }
        }
    }

    @ViewBuilder
    private func messageContent(style: ChatMessageStyle) -> some View {
        RichText(message: message, isUser: isUser, style: style)

        if !message.attachments.isEmpty {
            AttachmentGallery(attachments: message.attachments, isUser: isUser)
        }
    }
}

struct ChatMessageContainer<Content: View>: View {
    var style: ChatMessageStyle
    private let contentBuilder: ContentBuilder

    init(style: ChatMessageStyle, @ViewBuilder content: @escaping ContentBuilder) {
        self.style = style
        self.contentBuilder = content
    }

    typealias ContentBuilder = () -> Content

    var body: some View {
        let content = VStack(alignment: style.stackAlignment, spacing: DS.Spacing.sm) {
            contentBuilder()
        }
        .padding(style.contentInsets)
        .background(background)
        .overlay(border)

        if style.fillsWidth {
            content
                .frame(maxWidth: .infinity, alignment: style.contentAlignment)
                .applyingShadow(style.shadow)
        } else {
            content
                .fixedSize(horizontal: true, vertical: false)
                .frame(maxWidth: style.maxWidth, alignment: style.contentAlignment)
                .applyingShadow(style.shadow)
        }
    }

    @ViewBuilder
    private var background: some View {
        if let backgroundStyle = style.backgroundStyle {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .fill(backgroundStyle)
        }
    }

    @ViewBuilder
    private var border: some View {
        if let borderColor = style.borderColor {
            RoundedRectangle(cornerRadius: style.cornerRadius, style: .continuous)
                .stroke(borderColor, lineWidth: style.borderWidth)
        }
    }
}

struct ChatMessageStyle {
    struct Shadow {
        var color: Color
        var radius: CGFloat
        var x: CGFloat
        var y: CGFloat
    }

    var contentInsets: EdgeInsets
    var backgroundStyle: AnyShapeStyle?
    var borderColor: Color?
    var borderWidth: CGFloat
    var shadow: Shadow?
    var cornerRadius: CGFloat
    var maxWidth: CGFloat?
    var stackAlignment: HorizontalAlignment
    var contentAlignment: Alignment
    var fillsWidth: Bool

    static let user = ChatMessageStyle(
        contentInsets: EdgeInsets(top: DS.Spacing.sm2, leading: DS.Spacing.md, bottom: DS.Spacing.sm2, trailing: DS.Spacing.md),
        backgroundStyle: AnyShapeStyle(DS.Palette.primaryGradient),
        borderColor: nil,
        borderWidth: DS.BorderWidth.hairline,
        shadow: Shadow(
            color: DS.Shadow.card.color.opacity(0.4),
            radius: DS.Shadow.card.radius / 2,
            x: 0,
            y: DS.Shadow.card.y / 2
        ),
        cornerRadius: DS.Radius.lg,
        maxWidth: 320,
        stackAlignment: .trailing,
        contentAlignment: .trailing,
        fillsWidth: false
    )

    static let assistant = ChatMessageStyle(
        contentInsets: EdgeInsets(top: DS.Spacing.sm2, leading: 0, bottom: DS.Spacing.sm2, trailing: 0),
        backgroundStyle: nil,
        borderColor: nil,
        borderWidth: 0,
        shadow: nil,
        cornerRadius: DS.Radius.lg,
        maxWidth: nil,
        stackAlignment: .leading,
        contentAlignment: .leading,
        fillsWidth: true
    )
}

struct RichText: View {
    var message: ChatMessage
    var isUser: Bool
    var style: ChatMessageStyle

    var body: some View {
        ChatMarkdownText(
            markdown: message.content,
            isUser: isUser,
            fillsWidth: style.fillsWidth,
            horizontalAlignment: style.stackAlignment
        )
    }
}

struct ChatMarkdownText: View {
    var markdown: String
    var isUser: Bool
    var fillsWidth: Bool
    var horizontalAlignment: HorizontalAlignment

    private var frameAlignment: Alignment {
        if horizontalAlignment == .trailing { return .trailing }
        if horizontalAlignment == .center { return .center }
        return .leading
    }

    private var textAlignment: TextAlignment {
        if horizontalAlignment == .trailing { return .trailing }
        if horizontalAlignment == .center { return .center }
        return .leading
    }

    var body: some View {
        VStack(alignment: horizontalAlignment, spacing: DS.Spacing.sm) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
                    .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: frameAlignment)
            }
        }
        .frame(maxWidth: fillsWidth ? .infinity : nil, alignment: frameAlignment)
    }

    private enum MarkdownBlock {
        case heading(String)
        case bullets([String])
        case paragraph(String)
        case quote(String)
    }

    private var blocks: [MarkdownBlock] {
        var result: [MarkdownBlock] = []
        var bullets: [String] = []
        var paragraph: [String] = []
        var quotes: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty {
                result.append(.paragraph(paragraph.joined(separator: "\n")))
                paragraph.removeAll()
            }
        }

        func flushBullets() {
            if !bullets.isEmpty {
                result.append(.bullets(bullets))
                bullets.removeAll()
            }
        }

        func flushQuotes() {
            if !quotes.isEmpty {
                result.append(.quote(quotes.joined(separator: "\n")))
                quotes.removeAll()
            }
        }

        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: CharacterSet.whitespaces)
            if trimmed.hasPrefix("## ") {
                flushParagraph(); flushBullets(); flushQuotes()
                let heading = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                result.append(.heading(heading))
            } else if trimmed.hasPrefix("- ") {
                flushParagraph(); flushQuotes()
                let bullet = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                bullets.append(bullet)
            } else if trimmed.hasPrefix("> ") {
                flushParagraph(); flushBullets()
                let quote = String(trimmed.dropFirst(1)).trimmingCharacters(in: .whitespaces)
                quotes.append(quote)
            } else if trimmed.isEmpty {
                flushParagraph(); flushBullets(); flushQuotes()
            } else {
                flushBullets(); flushQuotes()
                paragraph.append(line)
            }
        }

        flushParagraph()
        flushBullets()
        flushQuotes()

        if result.isEmpty {
            result = [.paragraph(markdown)]
        }
        return result
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let text):
            Text(text)
                .dsType(DS.Font.section, lineSpacing: 4)
                .foregroundStyle(isUser ? DS.Palette.onPrimary : DS.Palette.primary)
        case .paragraph(let text):
            attributedText(text)
                .dsType(DS.Font.body, lineSpacing: 6)
                .multilineTextAlignment(textAlignment)
                .foregroundStyle(isUser ? DS.Palette.onPrimary : .primary)
        case .bullets(let items):
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(isUser ? DS.Palette.onPrimary.opacity(0.9) : DS.Palette.primary)
                            .frame(width: 6, height: 6)
                            .padding(.top, 6)
                        attributedText(item)
                            .dsType(DS.Font.body, lineSpacing: 6)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(isUser ? DS.Palette.onPrimary : .primary)
                    }
                }
            }
        case .quote(let text):
            attributedText(text)
                .dsType(DS.Font.body, lineSpacing: 6)
                .foregroundStyle(isUser ? DS.Palette.onPrimary.opacity(0.8) : .secondary)
                .padding(.leading, DS.Spacing.sm)
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill((isUser ? DS.Palette.onPrimary : DS.Palette.primary).opacity(0.2))
                        .frame(width: 3)
                        .cornerRadius(1.5)
                }
        }
    }

    private func attributedText(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .full,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        if let attr = try? AttributedString(markdown: text, options: options) {
            return Text(attr)
        }
        return Text(text)
    }
}

struct AttachmentGallery: View {
    var attachments: [ChatAttachment]
    var isUser: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm2) {
                ForEach(attachments) { attachment in
                    AttachmentThumbnail(attachment: attachment, showRemove: false, onRemove: { _ in })
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
                                .stroke(isUser ? Color.white.opacity(0.5) : DS.Palette.border.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.hairline)
                        )
                }
            }
        }
    }
}

struct AttachmentThumbnail: View {
    var attachment: ChatAttachment
    var showRemove: Bool
    var onRemove: (ChatAttachment) -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                #if canImport(UIKit)
                if let image = attachment.uiImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    placeholder
                }
                #else
                placeholder
                #endif
            }
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous))

            if showRemove {
                Button {
                    onRemove(attachment)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
                .offset(x: 6, y: -6)
            }
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: DS.Radius.sm, style: .continuous)
            .fill(DS.Palette.surfaceAlt)
            .overlay(
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            )
    }
}

private extension View {
    @ViewBuilder
    func applyingShadow(_ style: ChatMessageStyle.Shadow?) -> some View {
        if let style {
            self.shadow(color: style.color, radius: style.radius, x: style.x, y: style.y)
        } else {
            self
        }
    }
}