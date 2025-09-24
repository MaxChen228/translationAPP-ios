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
    @State private var showClipboardTemplate: Bool = false

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
                        clipboardEntryCard

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

                        if let research = viewModel.researchDeck {
                            ChatResearchCard(deck: research)
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
            .task(id: viewModel.researchDeck?.id) {
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

            clipboardPreview

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
        .padding(.bottom, DS.Spacing.xs)
        .onChange(of: pendingPhotoItem) { _, newValue in
            guard let item = newValue else { return }
            handleSelectedPhotoItem(item)
            pendingPhotoItem = nil
        }
        .sheet(isPresented: $showClipboardTemplate) {
            ClipboardTemplateSheet(template: viewModel.clipboardTemplateText) {
                viewModel.copyClipboardTemplate()
                Haptics.lightTick()
            }
            .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var clipboardPreview: some View {
        if viewModel.clipboardImportDeck != nil {
            EmptyView()
        } else {
            switch viewModel.clipboardParseState {
            case .notMatched:
                EmptyView()
            case .success(let deck):
                ClipboardReadyCard(deck: deck, onImport: {
                    viewModel.importClipboardDeck()
                    Haptics.lightTick()
                })
            case .failure(let message):
                ClipboardErrorCard(message: message)
            }
        }
    }

    private var canSend: Bool {
        guard !viewModel.isLoading else { return false }
        if case .success = viewModel.clipboardParseState { return false }
        if viewModel.clipboardImportDeck != nil { return false }
        let hasText = !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return hasText || !pendingAttachments.isEmpty
    }

    private var canRunResearch: Bool {
        !viewModel.isLoading && viewModel.state == .ready && viewModel.messages.contains { $0.role == .user }
    }

    private var shouldShowResearchButton: Bool {
        canRunResearch && viewModel.researchDeck == nil
    }

    private var canReset: Bool {
        viewModel.messages.contains { $0.role == .user } || !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.researchDeck != nil || (viewModel.checklist?.isEmpty == false) || !pendingAttachments.isEmpty
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
        if let research = viewModel.researchDeck { return .research(research.id) }
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

private extension ChatWorkspaceView {
    private var clipboardEntryCard: some View {
        ClipboardEntryCard(
            deck: viewModel.clipboardImportDeck,
            errorMessage: viewModel.clipboardImportError,
            onLoadClipboard: {
                viewModel.loadClipboardFromPasteboard()
                Haptics.lightTick()
            },
            onImport: {
                viewModel.importClipboardDeck()
                Haptics.success()
            },
            onClear: {
                viewModel.clearClipboardImport()
            },
            onTemplate: {
                showClipboardTemplate = true
            }
        )
        .transition(.opacity)
    }
}

private struct ClipboardReadyCard: View {
    var deck: ChatResearchDeck
    var onImport: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        DSOutlineCard(fill: DS.Palette.surface) {
            Label {
                Text(String(localized: String.LocalizationValue("chat.clipboard.ready.title"), locale: locale))
                    .dsType(DS.Font.section)
            } icon: {
                Image(systemName: "tray.and.arrow.down.fill")
                    .foregroundStyle(DS.Palette.primary)
            }

            let countText = String(format: String(localized: String.LocalizationValue("deck.cards.count"), locale: locale), deck.cards.count)
            Text(String(format: String(localized: String.LocalizationValue("chat.clipboard.ready.summary"), locale: locale), deck.name, countText))
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)

            Button(action: onImport) {
                Text(String(localized: String.LocalizationValue("chat.clipboard.action.import"), locale: locale))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DSButton(style: .primary, size: .full))
        }
    }
}

private struct ClipboardErrorCard: View {
    var message: String
    @Environment(\.locale) private var locale

    var body: some View {
        DSOutlineCard(fill: DS.Palette.surface) {
            Label {
                Text(String(localized: String.LocalizationValue("chat.clipboard.error.title"), locale: locale))
                    .dsType(DS.Font.section)
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(DS.Palette.danger)
            }

            Text(message)
                .dsType(DS.Font.caption)
                .foregroundStyle(DS.Palette.danger)
        }
    }
}

private struct ClipboardEntryCard: View {
    var deck: ChatResearchDeck?
    var errorMessage: String?
    var onLoadClipboard: () -> Void
    var onImport: () -> Void
    var onClear: () -> Void
    var onTemplate: () -> Void
    @Environment(\.locale) private var locale

    var body: some View {
        DSOutlineCard(fill: DS.Palette.surface) {
            Label {
                Text(String(localized: String.LocalizationValue("chat.clipboard.entry.title"), locale: locale))
                    .dsType(DS.Font.section)
            } icon: {
                Image(systemName: "doc.on.clipboard")
                    .foregroundStyle(DS.Palette.primary)
            }

            if let deck {
                let countText = String(format: String(localized: String.LocalizationValue("deck.cards.count"), locale: locale), deck.cards.count)
                Text(String(format: String(localized: String.LocalizationValue("chat.clipboard.ready.summary"), locale: locale), deck.name, countText))
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)

                Button(action: onImport) {
                    Text(String(localized: String.LocalizationValue("chat.clipboard.action.importNow"), locale: locale))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSButton(style: .primary, size: .full))

                Button(action: onClear) {
                    Text(String(localized: String.LocalizationValue("chat.clipboard.action.clear"), locale: locale))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSButton(style: .secondary, size: .full))
            } else if let errorMessage {
                Text(errorMessage)
                    .dsType(DS.Font.caption)
                    .foregroundStyle(DS.Palette.danger)

                Button(action: onLoadClipboard) {
                    Text(String(localized: String.LocalizationValue("chat.clipboard.action.reload"), locale: locale))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSButton(style: .primary, size: .full))

                Button(action: onTemplate) {
                    Text(String(localized: String.LocalizationValue("chat.clipboard.action.template"), locale: locale))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSButton(style: .secondary, size: .full))
            } else {
                Text(String(localized: String.LocalizationValue("chat.clipboard.entry.description"), locale: locale))
                    .dsType(DS.Font.caption)
                    .foregroundStyle(.secondary)

                Button(action: onLoadClipboard) {
                    Text(String(localized: String.LocalizationValue("chat.clipboard.action.load"), locale: locale))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSButton(style: .primary, size: .full))

                Button(action: onTemplate) {
                    Text(String(localized: String.LocalizationValue("chat.clipboard.action.template"), locale: locale))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DSButton(style: .secondary, size: .full))
            }
        }
    }
}

private struct ClipboardTemplateSheet: View {
    var template: String
    var onCopy: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    Text(String(localized: String.LocalizationValue("chat.clipboard.template.instructions"), locale: locale))
                        .dsType(DS.Font.body)
                        .foregroundStyle(.primary)

                    Text(template)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(DS.Palette.surfaceAlt.opacity(DS.Opacity.fill), in: RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous))
                        .textSelection(.enabled)
                }
                .padding()
            }
            .navigationTitle(Text(String(localized: String.LocalizationValue("chat.clipboard.template.title"), locale: locale)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(String(localized: String.LocalizationValue("chat.clipboard.template.copy"), locale: locale)) {
                        onCopy()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel", locale: locale)) { dismiss() }
                }
            }
        }
    }
}












