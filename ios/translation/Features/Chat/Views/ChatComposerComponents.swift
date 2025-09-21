import SwiftUI
import UIKit

struct AdaptiveComposer: View {
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
struct GrowingTextView: UIViewRepresentable {
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
struct GrowingTextView: View {
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