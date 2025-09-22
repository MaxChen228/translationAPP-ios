import SwiftUI
import OSLog

struct AdaptiveComposer: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var minHeight: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 32
        case .medium: return 34
        case .large: return 36
        case .xLarge: return 38
        case .xxLarge: return 40
        case .xxxLarge: return 42
        default: return 44
        }
    }

    private var maxHeight: CGFloat {
        minHeight * 3.5  // 約3.5行，而非5行
    }


    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder text
            if text.isEmpty {
                Text("chat.placeholder")
                    .dsType(DS.Font.body)
                    .foregroundStyle(DS.Palette.subdued)
                    .padding(.top, 6)
                    .padding(.horizontal, 16)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }

            // Native TextEditor
            TextEditor(text: $text)
                .dsType(DS.Font.body)
                .focused($isFocused)
                .frame(minHeight: minHeight, maxHeight: maxHeight)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .accessibilityLabel("Message input")
                .accessibilityHint("Type your message here")
        }
        .frame(minHeight: minHeight + 12, maxHeight: maxHeight + 12)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(isFocused ? DS.Palette.primary.opacity(DS.Opacity.strong) : DS.Palette.border.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.thin)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            AppLog.chatDebug("AdaptiveComposer tap gesture - current isFocused: \(isFocused)")
            if !isFocused {
                AppLog.chatDebug("Setting isFocused to true from tap gesture")
                isFocused = true
            }
        }
        .dsAnimation(DS.AnimationToken.subtle, value: isFocused)
        .onChange(of: text) { oldValue, newValue in
            AppLog.chatDebug("Text changed from '\(oldValue)' to '\(newValue)'")
        }
        .onChange(of: isFocused) { oldValue, newValue in
            AppLog.chatDebug("Focus changed from \(oldValue) to \(newValue)")
        }
    }
}

// UIKit imports removed - now using pure SwiftUI

struct AttachmentPreviewStrip: View {
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