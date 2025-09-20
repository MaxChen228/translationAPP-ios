import SwiftUI
import PhotosUI
import UIKit
import Foundation

/// 主聊天工作區，提供訊息串、研究結果與輸入列。
struct ChatWorkspaceView: View {
    @StateObject private var viewModel: ChatViewModel
    @FocusState private var isComposerFocused: Bool
    @State private var pendingAttachments: [ChatAttachment] = []
    @State private var pendingPhotoItem: PhotosPickerItem? = nil

    private enum ScrollAnchor: Hashable {
        case message(UUID)
        case checklist
        case research(UUID)
        case typing
    }

    @MainActor
    init(viewModel: ChatViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    @MainActor
    init() {
        self.init(viewModel: ChatViewModel())
    }

    var body: some View {
        VStack(spacing: 0) {
            conversation
            composer
        }
        .navigationTitle(Text("chat.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    viewModel.reset()
                    pendingAttachments.removeAll()
                    isComposerFocused = false
                } label: {
                    Label("chat.reset", systemImage: "arrow.counterclockwise")
                }
                .disabled(!canReset)
            }
        }
        .background(DS.Palette.background.ignoresSafeArea())
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ZStack(alignment: .top) {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DS.Spacing.md) {
                        ForEach(viewModel.messages) { message in
                            ChatBubble(message: message)
                                .id(ScrollAnchor.message(message.id))
                        }

                        if let checklist = viewModel.checklist, !checklist.isEmpty {
                            ChatChecklistCard(
                                titleKey: "chat.checklist",
                                items: checklist,
                                showResearchButton: shouldShowResearchButton,
                                isResearchButtonEnabled: canRunResearch,
                                onResearch: {
                                    Task { await viewModel.runResearch() }
                                }
                            )
                                .id(ScrollAnchor.checklist)
                        }

                        if let research = viewModel.researchResult {
                            ChatResearchCard(response: research)
                                .id(ScrollAnchor.research(research.id))
                        }

                        if viewModel.isLoading {
                            TypingIndicator()
                                .id(ScrollAnchor.typing)
                        }
                    }
                    .padding(.vertical, DS.Spacing.lg)
                    .padding(.horizontal, DS.Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .background(DS.Palette.background)

                if shouldShowEmptyState {
                    ChatEmptyStateView(onSuggestionTap: handleSuggestion)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.top, DS.Spacing.lg)
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(TapGesture().onEnded { dismissKeyboard() })
            .task(id: viewModel.messages.last?.id) {
                await MainActor.run { scrollToLatest(proxy) }
            }
            .task(id: viewModel.checklist?.count ?? 0) {
                await MainActor.run { scrollToLatest(proxy) }
            }
            .task(id: viewModel.researchResult?.id) {
                await MainActor.run { scrollToLatest(proxy) }
            }
            .task(id: viewModel.isLoading) {
                await MainActor.run { scrollToLatest(proxy) }
            }
            .task {
                await MainActor.run { scrollToLatest(proxy, animated: false) }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: DS.Spacing.sm) {
            if let error = viewModel.errorMessage, !error.isEmpty {
                ErrorBanner(text: error)
            }

            if !pendingAttachments.isEmpty {
                AttachmentPreviewStrip(attachments: pendingAttachments, onRemove: removeAttachment)
            }

            ChatStateBadge(state: viewModel.state, isLoading: viewModel.isLoading)
                .frame(maxWidth: .infinity, alignment: .leading)

            AdaptiveComposer(text: $viewModel.inputText, isFocused: $isComposerFocused)

            HStack(alignment: .center, spacing: DS.Spacing.sm) {
                PhotosPicker(selection: $pendingPhotoItem, matching: .images, photoLibrary: .shared()) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DS.Brand.scheme.classicBlue)
                        .padding(10)
                        .background(
                            Circle().fill(DS.Brand.scheme.babyBlue.opacity(DS.Opacity.fill))
                        )
                }
                .disabled(viewModel.isLoading)

                Spacer(minLength: DS.Spacing.sm)

                Button {
                    let attachments = pendingAttachments
                    Task {
                        await viewModel.sendMessage(attachments: attachments)
                        await MainActor.run { pendingAttachments.removeAll() }
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(DS.Palette.onPrimary)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 18)
                        .background(
                            Capsule(style: .continuous)
                                .fill(DS.Palette.primary)
                        )
                }
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.sm)
        .background(DS.Palette.surfaceAlt)
        .onChange(of: pendingPhotoItem) { _, newValue in
            guard let item = newValue else { return }
            handleSelectedPhotoItem(item)
            pendingPhotoItem = nil
        }
    }

    private var canSend: Bool {
        guard !viewModel.isLoading else { return false }
        let hasText = !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText || !pendingAttachments.isEmpty
    }

    private var canRunResearch: Bool {
        !viewModel.isLoading && viewModel.state == .ready && viewModel.messages.contains { $0.role == .user }
    }

    private var shouldShowResearchButton: Bool {
        canRunResearch && (viewModel.researchResult?.items.isEmpty ?? true)
    }

    private var canReset: Bool {
        viewModel.messages.contains { $0.role == .user } || !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.researchResult != nil || (viewModel.checklist?.isEmpty == false) || !pendingAttachments.isEmpty
    }

    private var shouldShowEmptyState: Bool {
        !viewModel.messages.contains { $0.role == .user }
            && viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && pendingAttachments.isEmpty
    }

    @MainActor
    private func scrollToLatest(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard let target = latestAnchor else { return }
        if animated {
            withAnimation(DS.AnimationToken.subtle) {
                proxy.scrollTo(target, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }

    private var latestAnchor: ScrollAnchor? {
        if viewModel.isLoading { return .typing }
        if let research = viewModel.researchResult { return .research(research.id) }
        if let checklist = viewModel.checklist, !checklist.isEmpty { return .checklist }
        if let last = viewModel.messages.last { return .message(last.id) }
        return nil
    }

    private func handleSuggestion(_ suggestion: String) {
        viewModel.inputText = suggestion
        isComposerFocused = true
    }

    private func dismissKeyboard() {
        isComposerFocused = false
#if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
#endif
    }

    private func removeAttachment(_ attachment: ChatAttachment) {
        pendingAttachments.removeAll { $0.id == attachment.id }
    }

    private func handleSelectedPhotoItem(_ item: PhotosPickerItem) {
        Task {
            let currentCount = await MainActor.run { pendingAttachments.count }
            guard currentCount < 3 else { return }
            guard let data = try? await item.loadTransferable(type: Data.self) else { return }
            guard let prepared = prepareImageData(from: data) else { return }
            await MainActor.run {
                let attachment = ChatAttachment(kind: .image, mimeType: prepared.mime, data: prepared.data)
                pendingAttachments.append(attachment)
            }
        }
    }

    private func prepareImageData(from data: Data) -> (data: Data, mime: String)? {
        #if canImport(UIKit)
        guard let image = UIImage(data: data) else { return nil }
        let maxDimension: CGFloat = 1024
        let targetSize: CGSize
        let maxSide = max(image.size.width, image.size.height)
        if maxSide > maxDimension {
            let scale = maxDimension / maxSide
            targetSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        } else {
            targetSize = image.size
        }
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let scaled = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let jpegData = scaled.jpegData(compressionQuality: 0.75) else { return nil }
        return (jpegData, "image/jpeg")
        #else
        return nil
        #endif
    }
}

private struct AdaptiveComposer: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    @State private var measuredHeight: CGFloat = 38

    private let minHeight: CGFloat = 38
    private let maxHeight: CGFloat = 180

    private var clampedHeight: CGFloat {
        min(max(measuredHeight, minHeight), maxHeight)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                Text("chat.placeholder")
                    .dsType(DS.Font.body)
                    .foregroundStyle(DS.Palette.subdued)
                    .padding(.top, 10)
                    .padding(.horizontal, 12)
            }

            GrowingTextView(
                text: $text,
                calculatedHeight: $measuredHeight,
                isFocused: Binding(
                    get: { isFocused },
                    set: { isFocused = $0 }
                ),
                maxHeight: maxHeight
            )
            .frame(height: clampedHeight)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(isFocused ? DS.Palette.primary.opacity(DS.Opacity.strong) : DS.Palette.border.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.regular)
        )
        .dsAnimation(DS.AnimationToken.subtle, value: isFocused)
    }
}

#if canImport(UIKit)
private struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var calculatedHeight: CGFloat
    @Binding var isFocused: Bool
    var maxHeight: CGFloat

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.backgroundColor = .clear
        textView.isScrollEnabled = false
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.font = DS.DSUIFont.body()
        textView.delegate = context.coordinator
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }

        if isFocused && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFocused && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }

        recalculateHeight(for: uiView)
    }

    private func recalculateHeight(for textView: UITextView) {
        let targetSize = CGSize(width: textView.bounds.width == 0 ? UIScreen.main.bounds.width - 32 : textView.bounds.width, height: .greatestFiniteMagnitude)
        let size = textView.sizeThatFits(targetSize)
        textView.isScrollEnabled = size.height > maxHeight
        if calculatedHeight != size.height {
            DispatchQueue.main.async {
                calculatedHeight = size.height
            }
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextView

        init(parent: GrowingTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
            parent.recalculateHeight(for: textView)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if !parent.isFocused {
                DispatchQueue.main.async { self.parent.isFocused = true }
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if parent.isFocused {
                DispatchQueue.main.async { self.parent.isFocused = false }
            }
        }
    }
}
#endif

#if !canImport(UIKit)
private struct GrowingTextView: View {
    @Binding var text: String
    @Binding var calculatedHeight: CGFloat
    @Binding var isFocused: Bool
    var maxHeight: CGFloat

    var body: some View {
        TextEditor(text: $text)
            .frame(minHeight: calculatedHeight)
    }
}
#endif

private struct ChatBubble: View {
    var message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top) {
            if isUser {
                Spacer(minLength: 24)
                ChatMessageContainer(style: .user, isUser: true) {
                    messageContent
                }
            } else {
                ChatMessageContainer(style: .assistant, isUser: false) {
                    messageContent
                }
                Spacer(minLength: 24)
            }
        }
    }

    @ViewBuilder
    private var messageContent: some View {
        RichText(message: message, isUser: isUser)

        if !message.attachments.isEmpty {
            AttachmentGallery(attachments: message.attachments, isUser: isUser)
        }
    }
}

private struct ChatMessageContainer<Content: View>: View {
    var style: ChatMessageStyle
    var isUser: Bool
    private let contentBuilder: ContentBuilder

    init(style: ChatMessageStyle, isUser: Bool, @ViewBuilder content: @escaping ContentBuilder) {
        self.style = style
        self.isUser = isUser
        self.contentBuilder = content
    }

    typealias ContentBuilder = () -> Content

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: DS.Spacing.sm) {
            contentBuilder()
        }
        .padding(style.contentInsets)
        .frame(maxWidth: style.maxWidth ?? .infinity, alignment: isUser ? .trailing : .leading)
        .background(background)
        .overlay(border)
        .applyingShadow(style.shadow)
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

private struct ChatMessageStyle {
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
        maxWidth: 320
    )

    static let assistant = ChatMessageStyle(
        contentInsets: EdgeInsets(top: DS.Spacing.sm2, leading: 0, bottom: DS.Spacing.sm2, trailing: 0),
        backgroundStyle: nil,
        borderColor: nil,
        borderWidth: 0,
        shadow: nil,
        cornerRadius: DS.Radius.lg,
        maxWidth: nil
    )
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

private struct RichText: View {
    var message: ChatMessage
    var isUser: Bool

    var body: some View {
        ChatMarkdownText(markdown: message.content, isUser: isUser)
    }
}

private struct ChatMarkdownText: View {
    var markdown: String
    var isUser: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                blockView(block)
                    .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
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
                .multilineTextAlignment(isUser ? .trailing : .leading)
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

private struct AttachmentPreviewStrip: View {
    var attachments: [ChatAttachment]
    var onRemove: (ChatAttachment) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DS.Spacing.sm2) {
                ForEach(attachments) { attachment in
                    AttachmentThumbnail(attachment: attachment, showRemove: true, onRemove: onRemove)
                }
            }
            .padding(.horizontal, DS.Spacing.sm2)
        }
    }
}

private struct AttachmentGallery: View {
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

private struct ChatChecklistCard: View {
    var titleKey: LocalizedStringKey
    var items: [String]
    var showResearchButton: Bool = false
    var isResearchButtonEnabled: Bool = true
    var onResearch: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            HStack(alignment: .center, spacing: DS.Spacing.sm) {
                Label {
                    Text(titleKey).dsType(DS.Font.section)
                } icon: {
                    Image(systemName: "checklist")
                        .foregroundStyle(DS.Brand.scheme.classicBlue)
                }

                Spacer(minLength: 0)

                if showResearchButton, let onResearch {
                    Button(action: onResearch) {
                        Label("chat.research", systemImage: "doc.text.magnifyingglass")
                    }
                    .buttonStyle(DSSecondaryButtonCompact())
                    .disabled(!isResearchButtonEnabled)
                }
            }

            VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(DS.Palette.primary)
                            .padding(.top, 5)
                        Text(item)
                            .dsType(DS.Font.body, lineSpacing: 4)
                    }
                }
            }
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Palette.border.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.thin)
        )
    }
}

private struct AttachmentThumbnail: View {
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

private struct ChatResearchCard: View {
    var response: ChatResearchResponse
    @EnvironmentObject private var savedStore: SavedErrorsStore
    @EnvironmentObject private var bannerCenter: BannerCenter
    @State private var savedItemIDs: Set<UUID> = []
    @State private var isExpanded: Bool = false
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Button {
                guard !response.items.isEmpty else { return }
                withAnimation(DS.AnimationToken.subtle) { isExpanded.toggle() }
            } label: {
                HStack(alignment: .center, spacing: DS.Spacing.sm) {
                    Label {
                        Text("chat.researchResult").dsType(DS.Font.section)
                    } icon: {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(DS.Brand.scheme.peachQuartz)
                    }

                    Spacer(minLength: 0)

                    if !response.items.isEmpty {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if response.items.isEmpty {
                Text(String(localized: "chat.research.ready"))
                    .dsType(DS.Font.body)
                    .foregroundStyle(.secondary)
            } else if isExpanded {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(response.items) { item in
                        ResearchItemCard(
                            item: item,
                            isSaved: savedItemIDs.contains(item.id),
                            onSave: { saveItem(item) }
                        )
                    }
                }
            } else {
                Text(collapsedHint(for: response.items.count))
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Palette.border.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.thin)
        )
        .shadow(color: DS.Shadow.card.color, radius: DS.Shadow.card.radius, x: DS.Shadow.card.x, y: DS.Shadow.card.y)
        .onChange(of: response.id) { _, _ in
            savedItemIDs.removeAll()
            isExpanded = false
        }
    }

    private func saveItem(_ item: ChatResearchItem) {
        guard !savedItemIDs.contains(item.id) else { return }
        let payload = ResearchSavePayload(
            term: item.term,
            explanation: item.explanation,
            context: item.context,
            type: item.type,
            savedAt: Date()
        )
        savedStore.add(research: payload)
        savedItemIDs.insert(item.id)
        Haptics.success()
        bannerCenter.show(
            title: String(localized: "banner.researchSaved.title"),
            subtitle: item.term
        )
    }

    private func collapsedHint(for count: Int) -> String {
        let template = String(localized: "chat.research.collapsedHint", locale: locale)
        return String(format: template, locale: locale, count)
    }
}

private struct ResearchItemCard: View {
    var item: ChatResearchItem
    var isSaved: Bool
    var onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm2) {
                HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.sm2) {
                    TagLabel(text: item.type.displayName, color: item.type.color)
                    Text(item.term)
                        .dsType(DS.Font.section)
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }

                Text(item.explanation)
                    .dsType(DS.Font.body, lineSpacing: 4)
                    .foregroundStyle(.secondary)

                if !item.context.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("chat.research.context")
                            .dsType(DS.Font.caption)
                            .foregroundStyle(.secondary)
                        Text(item.context)
                            .dsType(DS.Font.body, lineSpacing: 4)
                            .foregroundStyle(.primary)
                    }
                }
            }

            DSSeparator(color: DS.Brand.scheme.babyBlue.opacity(0.35))

            HStack {
                Spacer()
                Button(action: onSave) {
                    if isSaved {
                        Label(String(localized: "chat.research.saved"), systemImage: "checkmark.seal.fill")
                    } else {
                        Label(String(localized: "chat.research.save"), systemImage: "tray.and.arrow.down")
                    }
                }
                .buttonStyle(DSSecondaryButtonCompact())
                .disabled(isSaved)
            }
        }
        .padding(DS.Spacing.md2)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(item.type.color.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.hairline)
                .overlay(
                    Rectangle()
                        .fill(item.type.color)
                        .frame(width: 3)
                        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                        .padding(.vertical, 6), alignment: .leading
                )
        )
    }
}

private struct TypingIndicator: View {
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(DS.Palette.primary)
            Text("chat.state.gathering")
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, DS.Spacing.sm2)
        .padding(.horizontal, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Palette.border.opacity(DS.Opacity.hairline), lineWidth: DS.BorderWidth.hairline)
        )
        .frame(maxWidth: 240, alignment: .leading)
    }
}

private struct ChatStateBadge: View {
    var state: ChatTurnResponse.State
    var isLoading: Bool

    private var displayState: ChatTurnResponse.State { isLoading ? .gathering : state }

    var body: some View {
        let color = tint(for: displayState)
        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            Text(title(for: displayState))
                .dsType(DS.Font.caption)
                .foregroundStyle(color)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(0.12))
        )
    }

    private func title(for state: ChatTurnResponse.State) -> LocalizedStringKey {
        switch state {
        case .gathering: return "chat.state.gathering"
        case .ready: return "chat.state.ready"
        case .completed: return "chat.state.completed"
        }
    }

    private func tint(for state: ChatTurnResponse.State) -> Color {
        switch state {
        case .gathering: return DS.Brand.scheme.babyBlue
        case .ready: return DS.Brand.scheme.classicBlue
        case .completed: return DS.Palette.success
        }
    }
}

private struct ChatEmptyStateView: View {
    @Environment(\.locale) private var locale
    var onSuggestionTap: (String) -> Void

    private struct SuggestionItem: Identifiable {
        let id = UUID()
        let key: String

        var localizedKey: LocalizedStringKey { LocalizedStringKey(key) }
        var resource: LocalizedStringResource { LocalizedStringResource(stringLiteral: key) }
        var localizationValue: String.LocalizationValue { String.LocalizationValue(stringLiteral: key) }
    }

    private struct SuggestionRow: View {
        var item: SuggestionItem
        var locale: Locale
        var onTap: (String) -> Void

        var body: some View {
            Button {
                let suggestion = String(localized: item.localizationValue, locale: locale)
                onTap(suggestion)
            } label: {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(DS.Brand.scheme.provence)
                    Text(item.localizedKey)
                        .dsType(DS.Font.body)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, DS.Spacing.sm2)
                .padding(.horizontal, DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                        .fill(DS.Brand.scheme.babyBlue.opacity(DS.Opacity.fill))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private let suggestions: [SuggestionItem] = [
        SuggestionItem(key: "chat.empty.suggestion1"),
        SuggestionItem(key: "chat.empty.suggestion2"),
        SuggestionItem(key: "chat.empty.suggestion3")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            VStack(alignment: .leading, spacing: 6) {
                Text("chat.empty.title")
                    .dsType(DS.Font.serifTitle)
                Text("chat.empty.subtitle")
                    .dsType(DS.Font.body, lineSpacing: 4)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(suggestions) { item in
                    SuggestionRow(item: item, locale: locale, onTap: onSuggestionTap)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                .stroke(DS.Palette.border.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.thin)
        )
    }
}

private struct ErrorBanner: View {
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DS.Palette.warning)
            Text(verbatim: text)
                .dsType(DS.Font.body, lineSpacing: 4)
                .foregroundStyle(DS.Palette.warning)
        }
        .padding(.vertical, DS.Spacing.sm2)
        .padding(.horizontal, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Palette.warning.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(DS.Palette.warning.opacity(0.5), lineWidth: DS.BorderWidth.hairline)
        )
    }
}
