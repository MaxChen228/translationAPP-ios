import SwiftUI
import OSLog

struct AdaptiveComposer: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var minHeight: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small: return 36
        case .medium: return 38
        case .large: return 40
        case .xLarge: return 42
        case .xxLarge: return 44
        case .xxxLarge: return 48
        default: return 52
        }
    }

    private var maxHeight: CGFloat {
        minHeight * 5
    }


    var body: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder text
            if text.isEmpty {
                Text("chat.placeholder")
                    .dsType(DS.Font.body)
                    .foregroundStyle(DS.Palette.subdued)
                    .padding(.top, 8)
                    .padding(.horizontal, 12)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }

            // Native TextEditor
            TextEditor(text: $text)
                .dsType(DS.Font.body)
                .focused($isFocused)
                .frame(minHeight: minHeight, maxHeight: maxHeight)
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .accessibilityLabel("Message input")
                .accessibilityHint("Type your message here")
        }
        .frame(minHeight: minHeight + 16, maxHeight: maxHeight + 16)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(isFocused ? DS.Palette.primary.opacity(DS.Opacity.strong) : DS.Palette.border.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.regular)
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