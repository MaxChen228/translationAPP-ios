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
            // 繼續對話橫幅
            if viewModel.showContinuationBanner {
                ContinuationBanner(
                    onResume: { Task { await viewModel.resumePendingRequest() } },
                    onDismiss: { viewModel.dismissContinuationBanner() }
                )
            }

            // 後台任務指示器
            if viewModel.isBackgroundActive {
                BackgroundTaskIndicator()
            }

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











