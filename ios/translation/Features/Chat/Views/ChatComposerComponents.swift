import SwiftUI
import UIKit

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
            if !isFocused {
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

        // Update text if different (prevent cursor jumping)
        if uiView.text != text {
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
            uiView.becomeFirstResponder()
        } else if !isFocused && wasFirstResponder {
            uiView.resignFirstResponder()
        }

        // Update height calculation with proper width
        context.coordinator.updateHeight(for: uiView, availableWidth: availableWidth)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: GrowingTextView
        private var lastCalculatedHeight: CGFloat = 0

        init(parent: GrowingTextView) {
            self.parent = parent
        }

        func updateHeight(for textView: UITextView, availableWidth: CGFloat) {
            let size = textView.sizeThatFits(CGSize(
                width: availableWidth,
                height: .greatestFiniteMagnitude
            ))

            let newHeight = size.height
            let shouldScroll = newHeight > parent.maxHeight

            if abs(newHeight - lastCalculatedHeight) > 0.5 {
                lastCalculatedHeight = newHeight

                DispatchQueue.main.async {
                    self.parent.calculatedHeight = newHeight
                    textView.isScrollEnabled = shouldScroll
                }
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            // Update text without affecting focus state
            let newText = textView.text ?? ""
            if parent.text != newText {
                parent.text = newText
            }
            updateHeight(for: textView, availableWidth: parent.availableWidth)
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            // Only update SwiftUI state if it's actually different
            // Use async to avoid blocking the UI
            if !parent.isFocused {
                DispatchQueue.main.async {
                    self.parent.isFocused = true
                }
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            // Only update SwiftUI state if it's actually different
            // Use async to avoid blocking the UI
            if parent.isFocused {
                DispatchQueue.main.async {
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