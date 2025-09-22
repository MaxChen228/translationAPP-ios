import SwiftUI

struct ErrorItemRow: View {
    var err: ErrorItem
    var selected: Bool
    var onSave: ((ErrorItem) -> Void)? = nil
    var isMergeMode: Bool = false
    var isMergeCandidate: Bool = false
    var isSelectedForMerge: Bool = false
    var isSelectionDisabled: Bool = false
    var isMerging: Bool = false
    var frameInResults: CGRect? = nil
    var pinchProgress: CGFloat = 0
    var pinchCentroid: CGPoint = .zero
    var isNewlyMerged: Bool = false

    @State private var showMergeGlow: Bool = false

    var body: some View {
        let theme = ErrorTheme.theme(for: err.type)
        VStack(alignment: .leading, spacing: DS.Spacing.xs2) {
            HStack(alignment: .firstTextBaseline, spacing: DS.Spacing.xs2) {
                TagLabel(text: err.type.displayName, color: err.type.color)
                Text(err.span)
                    .dsType(DS.Font.body)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
            }
            Text(err.explainZh)
                .dsType(DS.Font.body, lineSpacing: 4)
                .foregroundStyle(.secondary)
            if let s = err.suggestion, !s.isEmpty {
                HStack(spacing: DS.Spacing.xs2) {
                    Text("error.suggestion")
                        .dsType(DS.Font.caption)
                        .foregroundStyle(.secondary)
                    SuggestionChip(text: s, color: theme.base)
                }
            }
        }
        .padding(DS.Spacing.md2)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(DS.Palette.surface)
        )
        .overlay(alignment: .leading) {
            let isHighlighted = selected || isMergeCandidate || isSelectedForMerge
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(isHighlighted ? theme.base.opacity(0.7) : theme.border, lineWidth: isHighlighted ? DS.BorderWidth.regular : DS.BorderWidth.thin)
                .overlay(
                    Rectangle()
                        .fill(theme.base)
                        .opacity(isHighlighted ? 1 : 0.6)
                        .frame(width: DS.IconSize.dividerThin)
                        .clipShape(RoundedRectangle(cornerRadius: DS.Component.Stripe.cornerRadius, style: .continuous))
                        .padding(.vertical, DS.Component.Stripe.paddingVertical), alignment: .leading
                )
        }
        .overlay(alignment: .topTrailing) { selectionBadge(theme: theme) }
        .overlay(alignment: .bottomLeading) { EmptyView() }
        .modifier(SaveActionBar(onSave: onSave, err: err, isDisabled: isMerging || isMergeMode))
        .overlay { if isMerging { ProgressView().scaleEffect(0.9) } }
        .overlay(mergeGlow(theme: theme))
        .opacity(isSelectionDisabled ? 0.35 : 1)
        .scaleEffect(scaleAmount)
        .offset(mergeOffset())
        .animation(.easeOut(duration: 0.1), value: pinchProgress)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: isMergeCandidate)
        .onChange(of: isNewlyMerged) { _, newValue in
            if newValue {
                DSMotion.run(.snappy) { showMergeGlow = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    DSMotion.run(.smooth) { showMergeGlow = false }
                }
            }
        }
        .scaleEffect(isNewlyMerged ? 1.05 : 1)
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isNewlyMerged)
        .allowsHitTesting(!isSelectionDisabled)
    }

    private var scaleAmount: CGFloat {
        if isMerging { return 0.95 }
        if isMergeCandidate { return 1 - pinchProgress * 0.15 }
        return isNewlyMerged ? 1.05 : 1
    }

    private func mergeOffset() -> CGSize {
        guard isMergeCandidate, let frame = frameInResults else { return .zero }
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let dx = (pinchCentroid.x - center.x) * pinchProgress * 0.35
        let dy = (pinchCentroid.y - center.y) * pinchProgress * 0.35
        return CGSize(width: dx, height: dy)
    }

    @ViewBuilder
    private func mergeGlow(theme: ErrorTheme) -> some View {
        if showMergeGlow || isNewlyMerged {
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .stroke(theme.base.opacity(0.35), lineWidth: DS.BorderWidth.regular)
                .blur(radius: 6)
                .opacity(showMergeGlow ? 1 : 0)
        }
    }

    @ViewBuilder
    private func selectionBadge(theme: ErrorTheme) -> some View {
        if isMergeMode {
            let size: CGFloat = 24
            Circle()
                .strokeBorder(theme.base.opacity(0.4), lineWidth: DS.BorderWidth.thin)
                .background(
                    Circle()
                        .fill(isSelectedForMerge ? theme.base : Color.clear)
                )
                .overlay {
                    if isSelectedForMerge {
                        Image(systemName: "checkmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: size, height: size)
                .padding(DS.Spacing.xs)
                .opacity(isSelectionDisabled ? 0.4 : 1)
        }
    }
}

private struct SaveActionBar: ViewModifier {
    let onSave: ((ErrorItem) -> Void)?
    let err: ErrorItem
    let isDisabled: Bool
    @State private var didSave = false
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
            if let onSave {
                DSFooterActionBar {
                    HStack {
                        Spacer()
                        Button {
                            onSave(err)
                            DSMotion.run(DS.AnimationToken.subtle) { didSave = true }
                        } label: {
                            if didSave {
                                DSIconLabel(textKey: "action.saved", systemName: "checkmark.seal.fill")
                            } else {
                                DSIconLabel(textKey: "action.save", systemName: "tray.and.arrow.down")
                            }
                        }
                        .buttonStyle(DSButton(style: .secondary, size: .compact))
                        .disabled(didSave || isDisabled)
                    }
                }
            }
        }
    }
}
