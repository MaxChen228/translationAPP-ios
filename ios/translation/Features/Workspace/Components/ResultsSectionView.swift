import SwiftUI
import UIKit

struct ResultsSectionView: View {
    @Environment(\.locale) private var locale
    let res: AIResponse
    let inputZh: String
    let inputEn: String
    let highlights: [Highlight]
    let correctedHighlights: [Highlight]
    let errors: [ErrorItem]
    @Binding var selectedErrorID: UUID?
    @Binding var filterType: ErrorType?
    @Binding var popoverError: ErrorItem?
    @Binding var mode: ResultSwitcherCard.Mode
    let applySuggestion: (ErrorItem) -> Void
    let onSave: (ErrorItem) -> Void
    let onSavePracticeRecord: () -> Void

    @ObservedObject var mergeController: ErrorMergeController
    @ObservedObject var session: CorrectionSessionStore
    let onEnterMergeMode: (UUID) -> Void
    let onToggleSelection: (UUID) -> Void
    let onMergeConfirm: @Sendable () async -> Void
    let onCancelMerge: () -> Void

    @StateObject private var mergeAnimator = MergeAnimationCoordinator()

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            ResultSwitcherCard(
                score: res.score,
                grade: grade(for: res.score),
                inputZh: inputZh,
                inputEn: inputEn,
                corrected: res.corrected,
                originalHighlights: highlights,
                correctedHighlights: correctedHighlights,
                selectedErrorID: selectedErrorID,
                mode: $mode,
                commentary: res.commentary
            )

            DSSectionHeader(titleKey: "results.errors.title", subtitleKey: "results.errors.subtitle", accentUnderline: true)
            TypeChipsView(errors: res.errors, selection: $filterType)

            if errors.isEmpty {
                DSCard { Text("results.empty").foregroundStyle(.secondary) }
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(errors) { err in
                        let isSelected = mergeController.selection.contains(err.id)
                        let isDisabled = mergeController.isMergeMode && !isSelected && mergeController.selection.count >= 2
                        let isHidden = mergeAnimator.isHidden(err.id)
                        ErrorItemRow(
                            err: err,
                            selected: selectedErrorID == err.id,
                            onSave: { item in onSave(item) },
                            isMergeMode: mergeController.isMergeMode,
                            isMergeCandidate: isSelected,
                            isSelectedForMerge: isSelected,
                            isSelectionDisabled: isDisabled,
                            isMerging: isHidden ? false : mergeController.isMerging,
                            frameInResults: nil,
                            pinchProgress: 0,
                            pinchCentroid: .zero,
                            isNewlyMerged: mergeController.mergedHighlightID == err.id
                        )
                        .opacity(isHidden ? 0 : 1)
                        .allowsHitTesting(!isHidden)
                        .background(
                            GeometryReader { proxy in
                                Color.clear
                                    .preference(
                                        key: ErrorRowFramePreferenceKey.self,
                                        value: [err.id: proxy.frame(in: .named("resultsList"))]
                                    )
                            }
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if mergeController.isMergeMode {
                                onToggleSelection(err.id)
                            } else {
                                selectedErrorID = err.id
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.4) {
                            if !mergeController.isMergeMode {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onEnterMergeMode(err.id)
                            }
                        }
                    }
                }
            }

            Button {
                onSavePracticeRecord()
            } label: {
                Label {
                    Text("practice.save.record")
                } icon: {
                    Image(systemName: "square.and.arrow.down")
                }
            }
            .buttonStyle(DSButton(style: .secondary, size: .full))
            .frame(maxWidth: .infinity)
            .disabled(mergeController.isMergeMode)
        }
        .padding(.bottom, mergeController.isMergeMode ? DS.Spacing.xl : 0)
        .overlay(alignment: .bottom) {
            if mergeController.isMergeMode {
                MergeToolbar(
                    selectionCount: mergeController.selection.count,
                    canMerge: mergeController.selection.count == 2 && !mergeController.isMerging,
                    inFlight: mergeController.isMerging,
                    onMerge: onMergeConfirm,
                    onCancel: onCancelMerge
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .topLeading) {
            GeometryReader { proxy in
                if let context = mergeAnimator.overlayContext {
                    MergeOverlayView(
                        context: context,
                        collapseProgress: mergeAnimator.collapseProgress,
                        isFlipping: mergeAnimator.isFlipping,
                        flipAngle: mergeAnimator.flipAngle
                    )
                    .opacity(mergeAnimator.overlayOpacity)
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
                }
            }
            .allowsHitTesting(false)
        }
        .coordinateSpace(name: "resultsList")
        .onPreferenceChange(ErrorRowFramePreferenceKey.self) { frames in
            mergeAnimator.updateRowFrames(frames, errors: res.errors)
        }
        .onChange(of: mergeController.selection) { _, newValue in
            mergeAnimator.recordSelection(newValue)
        }
        .onChange(of: mergeController.isMerging) { _, newValue in
            mergeAnimator.mergeStateDidChange(isInFlight: newValue, errors: res.errors)
        }
        .onDisappear {
            mergeAnimator.reset()
        }
    }

    private func grade(for score: Int) -> String {
        switch score { case 90...: return "A"; case 80..<90: return "B"; case 70..<80: return "C"; case 60..<70: return "D"; default: return "E" }
    }
}

private struct MergeToolbar: View {
    let selectionCount: Int
    let canMerge: Bool
    let inFlight: Bool
    let onMerge: @Sendable () async -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack {
            Divider()
            HStack {
                Button {
                    onCancel()
                } label: {
                    Text("merge.button.cancel", comment: "Cancel merge mode")
                }
                .buttonStyle(DSButton(style: .secondary, size: .full))

                Spacer(minLength: DS.Spacing.md)

                Text(String.localizedStringWithFormat(NSLocalizedString("merge.selection.hint", comment: "Selection count"), selectionCount))
                    .dsType(DS.Font.body)
                    .foregroundStyle(.secondary)

                Spacer(minLength: DS.Spacing.md)

                Button {
                    Task { @MainActor in
                        await onMerge()
                    }
                } label: {
                    if inFlight {
                        ProgressView()
                            .progressViewStyle(.circular)
                    } else {
                        Text("merge.button.merge", comment: "Merge selected errors")
                    }
                }
                .buttonStyle(DSButton(style: .primary, size: .full))
                .disabled(!canMerge)
            }
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.md)
            .background(.thinMaterial)
        }
    }
}
