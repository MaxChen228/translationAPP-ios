import SwiftUI

/// 主聊天工作區，提供訊息串、研究結果與輸入列。
struct ChatWorkspaceView: View {
    @StateObject private var viewModel: ChatViewModel
    @FocusState private var isComposerFocused: Bool

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
                            ChatChecklistCard(titleKey: "chat.checklist", items: checklist)
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
        VStack(spacing: DS.Spacing.sm2) {
            if let error = viewModel.errorMessage, !error.isEmpty {
                ErrorBanner(text: error)
            }

            ZStack(alignment: .topLeading) {
                if viewModel.inputText.isEmpty {
                    Text("chat.placeholder")
                        .dsType(DS.Font.body, lineSpacing: 4, tracking: 0.1)
                        .foregroundStyle(DS.Palette.subdued)
                        .padding(.top, 8)
                        .padding(.horizontal, 6)
                }

                TextEditor(text: $viewModel.inputText)
                    .focused($isComposerFocused)
                    .frame(minHeight: 112, alignment: .leading)
                    .font(DS.Font.body)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .fill(DS.Palette.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                    .stroke(isComposerFocused ? DS.Palette.primary.opacity(DS.Opacity.strong) : DS.Palette.border.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.regular)
            )

            HStack(spacing: DS.Spacing.sm2) {
                ChatStateBadge(state: viewModel.state, isLoading: viewModel.isLoading)

                Spacer()

                Button {
                    Task { await viewModel.runResearch() }
                } label: {
                    Label("chat.research", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(DSSecondaryButtonCompact())
                .disabled(!canRunResearch)

                Button {
                    Task { await viewModel.sendMessage() }
                } label: {
                    Label("chat.send", systemImage: "paperplane.fill")
                }
                .buttonStyle(DSPrimaryButtonCompact())
                .disabled(!canSend)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.md)
        .background(DS.Palette.surfaceAlt)
    }

    private var canSend: Bool {
        !viewModel.isLoading && !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canRunResearch: Bool {
        !viewModel.isLoading && viewModel.messages.contains { $0.role == .user }
    }

    private var canReset: Bool {
        viewModel.messages.contains { $0.role == .user } || !viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.researchResult != nil || (viewModel.checklist?.isEmpty == false)
    }

    private var shouldShowEmptyState: Bool {
        !viewModel.messages.contains { $0.role == .user } && viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
}

private struct ChatBubble: View {
    var message: ChatMessage

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 24) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                Text(message.content)
                    .dsType(DS.Font.body, lineSpacing: 6)
                    .foregroundStyle(isUser ? DS.Palette.onPrimary : .primary)
                    .multilineTextAlignment(isUser ? .trailing : .leading)
            }
            .padding(.vertical, DS.Spacing.sm2)
            .padding(.horizontal, DS.Spacing.md)
            .background(
                Group {
                    if isUser {
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .fill(DS.Palette.primaryGradient)
                    } else {
                        RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                            .fill(DS.Palette.surface)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(isUser ? Color.clear : DS.Palette.border.opacity(DS.Opacity.hairline), lineWidth: DS.BorderWidth.hairline)
            )
            .frame(maxWidth: 360, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 24) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
}

private struct ChatChecklistCard: View {
    var titleKey: LocalizedStringKey
    var items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Label {
                Text(titleKey).dsType(DS.Font.section)
            } icon: {
                Image(systemName: "checklist")
                    .foregroundStyle(DS.Brand.scheme.classicBlue)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle")
                            .font(.caption)
                            .foregroundStyle(DS.Palette.primary.opacity(0.8))
                            .padding(.top, 4)
                        Text(verbatim: item)
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

private struct ChatResearchCard: View {
    var response: ChatResearchResponse

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Label {
                Text("chat.researchResult").dsType(DS.Font.section)
            } icon: {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(DS.Brand.scheme.peachQuartz)
            }

            if !response.title.isEmpty {
                Text(response.title)
                    .dsType(DS.Font.serifTitle)
            }

            Text(response.summary)
                .dsType(DS.Font.body, lineSpacing: 6)
                .foregroundStyle(.secondary)

            if let source = response.sourceZh, !source.isEmpty {
                section(titleKey: "chat.source") {
                    Text(source)
                        .dsType(DS.Font.body, lineSpacing: 4)
                }
            }

            if let attempt = response.attemptEn, !attempt.isEmpty {
                section(titleKey: "chat.attempt") {
                    Text(attempt)
                        .dsType(DS.Font.body, lineSpacing: 4)
                        .foregroundStyle(.secondary)
                }
            }

            section(titleKey: "chat.corrected") {
                Text(response.correctedEn)
                    .dsType(DS.Font.body, lineSpacing: 4)
            }

            if !response.errors.isEmpty {
                Text("chat.research.errors")
                    .dsType(DS.Font.section)

                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    ForEach(response.errors) { err in
                        ErrorItemRow(err: err, selected: false)
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

    @ViewBuilder
    private func section(titleKey: LocalizedStringKey, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(titleKey)
                .dsType(DS.Font.caption)
                .foregroundStyle(.secondary)
            content()
        }
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
        return HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title(for: displayState))
                .dsType(DS.Font.caption)
                .foregroundStyle(color)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(
            Capsule(style: .continuous)
                .fill(color.opacity(DS.Opacity.fill))
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
                .stroke(DS.Palette.warning.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.thin)
        )
    }
}

struct ChatWorkspaceView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ChatWorkspaceView()
        }
        .environment(\.locale, Locale(identifier: "zh-Hant"))
    }
}
