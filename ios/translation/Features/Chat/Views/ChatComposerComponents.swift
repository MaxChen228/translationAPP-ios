import SwiftUI
import UIKit
import OSLog
import QuartzCore

struct AdaptiveComposer: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    @State private var measuredHeight: CGFloat = 0
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

    private var effectiveHeight: CGFloat {
        measuredHeight == 0 ? minHeight : min(max(measuredHeight, minHeight), maxHeight)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("chat.placeholder")
                        .dsType(DS.Font.body)
                        .foregroundStyle(DS.Palette.subdued)
                        .padding(.top, 10)
                        .padding(.horizontal, 12)
                        .accessibilityHidden(true)
                }

                GrowingTextView(
                    text: $text,
                    calculatedHeight: $measuredHeight,
                    isFocused: Binding(
                        get: { isFocused },
                        set: { isFocused = $0 }
                    ),
                    maxHeight: maxHeight,
                    availableWidth: geometry.size.width - 16
                )
                .frame(height: effectiveHeight)
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
        }
        .frame(height: effectiveHeight + 16)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(isFocused ? DS.Palette.primary.opacity(DS.Opacity.strong) : DS.Palette.border.opacity(DS.Opacity.border), lineWidth: DS.BorderWidth.regular)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Text input")
        .accessibilityHint("Enter your message here")
        .contentShape(Rectangle())
        .onTapGesture {
            AppLog.chatDebug("AdaptiveComposer tap gesture - current isFocused: \(isFocused)")
            if !isFocused {
                AppLog.chatDebug("Setting isFocused to true from tap gesture")
                isFocused = true
            }
        }
        .dsAnimation(DS.AnimationToken.subtle, value: isFocused)
    }
}

#if canImport(UIKit)
struct GrowingTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var calculatedHeight: CGFloat
    @Binding var isFocused: Bool
    let maxHeight: CGFloat
    let availableWidth: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()

        textView.backgroundColor = .clear
        textView.textContainerInset = .zero
        textView.textContainer.lineFragmentPadding = 0
        textView.font = DS.DSUIFont.body()
        textView.delegate = context.coordinator

        textView.accessibilityLabel = "Message input"
        textView.accessibilityHint = "Type your message here"

        textView.autocorrectionType = .yes
        textView.autocapitalizationType = .sentences
        textView.spellCheckingType = .yes
        textView.smartQuotesType = .yes
        textView.smartDashesType = .yes
        textView.smartInsertDeleteType = .yes

        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        textView.setContentCompressionResistancePriority(.required, for: .vertical)
        textView.setContentHuggingPriority(.defaultHigh, for: .vertical)

        textView.isScrollEnabled = false

        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        // Store the current first responder status to avoid unnecessary changes
        let wasFirstResponder = uiView.isFirstResponder
        AppLog.chatDebug("updateUIView - isFocused: \(isFocused), wasFirstResponder: \(wasFirstResponder), text: '\(text)'")

        // Update text if different (prevent cursor jumping)
        if uiView.text != text {
            AppLog.chatDebug("Updating UITextView text from '\(uiView.text ?? "")' to '\(text)'")
            let selectedRange = uiView.selectedRange
            uiView.text = text
            // Restore cursor position if still valid
            if selectedRange.location <= text.count {
                uiView.selectedRange = selectedRange
            }
        }

        // Update font for Dynamic Type
        let currentFont = DS.DSUIFont.body()
        if uiView.font != currentFont {
            uiView.font = currentFont
        }

        // Only handle focus changes if there's actually a change needed
        // This prevents unnecessary resignFirstResponder calls during typing
        if isFocused && !wasFirstResponder {
            AppLog.chatDebug("Becoming first responder")
            uiView.becomeFirstResponder()
        } else if !isFocused && wasFirstResponder {
            // Don't resign first responder if there's text (user might be typing)
            // This prevents the keyboard from disappearing during text input
            if text.isEmpty {
                AppLog.chatDebug("Resigning first responder (text is empty)")
                uiView.resignFirstResponder()
            } else {
                AppLog.chatDebug("NOT resigning first responder (text exists: '\(text)')")
                // Keep the focus if there's text - user is likely still typing
            }
        }

        // Don't update height here to prevent AttributeGraph cycles
        // Height updates are handled in textViewDidChange only
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextView
        private var lastCalculatedHeight: CGFloat = 0
        private var heightUpdateWorkItem: DispatchWorkItem?

        init(parent: GrowingTextView) {
            self.parent = parent
        }

        func updateHeight(for textView: UITextView, availableWidth: CGFloat) {
            // Cancel previous height update to prevent rapid updates
            heightUpdateWorkItem?.cancel()

            let workItem = DispatchWorkItem { [weak self] in
                self?.updateHeightSync(for: textView, availableWidth: availableWidth)
            }

            heightUpdateWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.01, execute: workItem)
        }

        func updateHeightSync(for textView: UITextView, availableWidth: CGFloat) {
            let size = textView.sizeThatFits(CGSize(
                width: availableWidth,
                height: .greatestFiniteMagnitude
            ))

            let newHeight = size.height
            let shouldScroll = newHeight > parent.maxHeight

            if abs(newHeight - lastCalculatedHeight) > 0.5 {
                lastCalculatedHeight = newHeight
                AppLog.chatDebug("Height changing from \(parent.calculatedHeight) to \(newHeight)")

                // Update synchronously in the current transaction
                parent.calculatedHeight = newHeight
                textView.isScrollEnabled = shouldScroll
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            let newText = textView.text ?? ""
            AppLog.chatDebug("textViewDidChange - old: '\(parent.text)', new: '\(newText)'")

            // Batch all state updates together to prevent AttributeGraph cycles
            DispatchQueue.main.async {
                // Use implicit transaction to batch state updates
                CATransaction.begin()
                CATransaction.setDisableActions(true)

                // Update text if different
                if self.parent.text != newText {
                    self.parent.text = newText
                    AppLog.chatDebug("Updated parent text to: '\(newText)'")
                }

                // Ensure focus state is correct when typing
                if !self.parent.isFocused && textView.isFirstResponder {
                    AppLog.chatDebug("Text changed while not focused - setting isFocused to true")
                    self.parent.isFocused = true
                }

                // Update height in the same transaction
                self.updateHeightSync(for: textView, availableWidth: self.parent.availableWidth)

                CATransaction.commit()
            }
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            AppLog.chatDebug("textViewDidBeginEditing - current isFocused: \(parent.isFocused)")
            // Focus state is primarily managed in textViewDidChange to avoid conflicts
            // Only update if we're sure we need to
            if !parent.isFocused {
                DispatchQueue.main.async {
                    AppLog.chatDebug("Setting isFocused to true from didBeginEditing")
                    self.parent.isFocused = true
                }
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            AppLog.chatDebug("textViewDidEndEditing - current isFocused: \(parent.isFocused)")
            // Only update focus if we're sure editing ended
            if parent.isFocused {
                DispatchQueue.main.async {
                    AppLog.chatDebug("Setting isFocused to false from didEndEditing")
                    self.parent.isFocused = false
                }
            }
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            if !text.isEmpty {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred(intensity: 0.3)
            }
            return true
        }
    }
}
#endif

#if !canImport(UIKit)
struct GrowingTextView: View {
    @Binding var text: String
    @Binding var calculatedHeight: CGFloat
    @Binding var isFocused: Bool
    let maxHeight: CGFloat
    let availableWidth: CGFloat

    var body: some View {
        TextEditor(text: $text)
            .frame(minHeight: max(calculatedHeight, 38))
            .accessibilityLabel("Message input")
            .accessibilityHint("Type your message here")
    }
}
#endif

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