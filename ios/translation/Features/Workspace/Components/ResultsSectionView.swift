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

    // Merge mode props
    let isMergeMode: Bool
    let mergeSelection: [UUID]
    let mergeInFlight: Bool
    let mergedHighlightID: UUID?
    let onEnterMergeMode: (UUID) -> Void
    let onToggleSelection: (UUID) -> Void
    let onMergeConfirm: @Sendable () async -> Void
    let onCancelMerge: () -> Void

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
                mode: $mode
            )

            DSSectionHeader(titleKey: "results.errors.title", subtitleKey: "results.errors.subtitle", accentUnderline: true)
            TypeChipsView(errors: res.errors, selection: $filterType)

            if errors.isEmpty {
                DSCard { Text("results.empty").foregroundStyle(.secondary) }
            } else {
                VStack(alignment: .leading, spacing: DS.Spacing.md) {
                    ForEach(errors) { err in
                        let isSelected = mergeSelection.contains(err.id)
                        let isDisabled = isMergeMode && !isSelected && mergeSelection.count >= 2
                        ErrorItemRow(
                            err: err,
                            selected: selectedErrorID == err.id,
                            onSave: { item in onSave(item) },
                            isMergeMode: isMergeMode,
                            isMergeCandidate: isSelected,
                            isSelectedForMerge: isSelected,
                            isSelectionDisabled: isDisabled,
                            isMerging: mergeInFlight,
                            frameInResults: nil,
                            pinchProgress: 0,
                            pinchCentroid: .zero,
                            isNewlyMerged: mergedHighlightID == err.id
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isMergeMode {
                                onToggleSelection(err.id)
                            } else {
                                selectedErrorID = err.id
                            }
                        }
                        .onLongPressGesture(minimumDuration: 0.4) {
                            if !isMergeMode {
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
            .disabled(isMergeMode)
        }
        .padding(.bottom, isMergeMode ? DS.Spacing.xl : 0)
        .overlay(alignment: .bottom) {
            if isMergeMode {
                MergeToolbar(
                    selectionCount: mergeSelection.count,
                    canMerge: mergeSelection.count == 2 && !mergeInFlight,
                    inFlight: mergeInFlight,
                    onMerge: onMergeConfirm,
                    onCancel: onCancelMerge
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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
                    Task { await onMerge() }
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
