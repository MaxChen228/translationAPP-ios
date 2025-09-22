import SwiftUI

@MainActor
final class MergeAnimationCoordinator: ObservableObject {
    struct Context {
        let topItem: ErrorItem
        let bottomItem: ErrorItem
        let topFrame: CGRect
        let bottomFrame: CGRect
    }

    @Published private(set) var overlayContext: Context? = nil
    @Published private(set) var collapseProgress: CGFloat = 0
    @Published private(set) var isFlipping: Bool = false
    @Published private(set) var flipAngle: Double = 0
    @Published private(set) var overlayOpacity: Double = 1
    @Published private(set) var hiddenIDs: Set<UUID> = []

    private var rowFrames: [UUID: CGRect] = [:]
    private var selectionSnapshot: [UUID] = []
    private var pendingOverlayStart: Bool = false
    private var flipTask: Task<Void, Never>? = nil
    private var fadeTask: Task<Void, Never>? = nil
    private var isMerging: Bool = false

    func updateRowFrames(_ frames: [UUID: CGRect], errors: [ErrorItem]) {
        let validIDs = Set(errors.map { $0.id })
        rowFrames = rowFrames.filter { validIDs.contains($0.key) }
        rowFrames.merge(frames) { _, new in new }
        if pendingOverlayStart {
            attemptStartOverlay(with: errors)
        }
    }

    func recordSelection(_ selection: [UUID]) {
        guard !selection.isEmpty else { return }
        selectionSnapshot = selection
    }

    func mergeStateDidChange(isInFlight: Bool, errors: [ErrorItem]) {
        isMerging = isInFlight
        if isInFlight {
            attemptStartOverlay(with: errors)
        } else {
            stopOverlay()
        }
    }

    func reset() {
        isMerging = false
        pendingOverlayStart = false
        selectionSnapshot = []
        rowFrames = [:]
        stopOverlay(immediate: true)
    }

    func isHidden(_ id: UUID) -> Bool {
        hiddenIDs.contains(id)
    }

    private func attemptStartOverlay(with errors: [ErrorItem]) {
        guard isMerging, overlayContext == nil else { return }
        guard selectionSnapshot.count == 2, let topID = selectionSnapshot.last else {
            pendingOverlayStart = true
            return
        }
        let bottomID = selectionSnapshot.first { $0 != topID } ?? topID
        guard let topFrame = rowFrames[topID], let bottomFrame = rowFrames[bottomID] else {
            pendingOverlayStart = true
            return
        }
        guard let topItem = errors.first(where: { $0.id == topID }),
              let bottomItem = errors.first(where: { $0.id == bottomID }) else {
            pendingOverlayStart = true
            return
        }

        pendingOverlayStart = false
        hiddenIDs = [topID, bottomID]
        fadeTask?.cancel()
        fadeTask = nil

        overlayContext = Context(
            topItem: topItem,
            bottomItem: bottomItem,
            topFrame: topFrame,
            bottomFrame: bottomFrame
        )
        overlayOpacity = 1
        collapseProgress = 0
        isFlipping = false
        flipAngle = 0

        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
            collapseProgress = 1
        }

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 320_000_000)
            await self?.beginFlipLoop()
        }
    }

    private func beginFlipLoop() async {
        guard isMerging, overlayContext != nil else { return }
        flipTask?.cancel()
        flipTask = Task { [weak self] in
            guard let self else { return }
            await self.runFlipLoop()
        }
    }

    private func runFlipLoop() async {
        await MainActor.run {
            self.isFlipping = true
        }

        while !Task.isCancelled {
            guard isMerging, overlayContext != nil else { break }
            await MainActor.run {
                withAnimation(.timingCurve(0.25, 0.9, 0.4, 1, duration: 0.32)) {
                    flipAngle = (flipAngle + 180).truncatingRemainder(dividingBy: 360)
                }
            }
            try? await Task.sleep(nanoseconds: 320_000_000)
            guard isMerging, overlayContext != nil else { break }
            try? await Task.sleep(nanoseconds: 180_000_000)
        }

        await MainActor.run {
            isFlipping = false
        }
    }

    private func stopOverlay(immediate: Bool = false) {
        pendingOverlayStart = false
        flipTask?.cancel()
        flipTask = nil

        if immediate || overlayContext == nil {
            fadeTask?.cancel()
            fadeTask = nil
            overlayContext = nil
            collapseProgress = 0
            isFlipping = false
            overlayOpacity = 1
            flipAngle = 0
            hiddenIDs = []
            return
        }

        fadeTask?.cancel()
        fadeTask = Task { [weak self] in
            guard let self else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.12)) {
                    overlayOpacity = 0
                }
            }
            try? await Task.sleep(nanoseconds: 140_000_000)
            await MainActor.run {
                overlayContext = nil
                collapseProgress = 0
                isFlipping = false
                overlayOpacity = 1
                flipAngle = 0
                hiddenIDs = []
            }
        }
    }
}

struct MergeOverlayView: View {
    let context: MergeAnimationCoordinator.Context
    let collapseProgress: CGFloat
    let isFlipping: Bool
    let flipAngle: Double

    var body: some View {
        ZStack {
            if isFlipping {
                MergeAnimatingCard(error: context.bottomItem)
                    .frame(width: context.bottomFrame.width, height: context.bottomFrame.height)
                    .position(x: context.bottomFrame.midX, y: context.bottomFrame.midY)
                    .rotation3DEffect(
                        .degrees(flipAngle),
                        axis: (x: 0, y: 1, z: 0),
                        perspective: 0.65
                    )
            } else {
                MergeAnimatingCard(error: context.bottomItem)
                    .frame(width: context.bottomFrame.width, height: context.bottomFrame.height)
                    .position(x: context.bottomFrame.midX, y: context.bottomFrame.midY)

                let startCenter = CGPoint(x: context.topFrame.midX, y: context.topFrame.midY)
                let endCenter = CGPoint(x: context.bottomFrame.midX, y: context.bottomFrame.midY)
                let currentCenter = CGPoint(
                    x: startCenter.x + (endCenter.x - startCenter.x) * collapseProgress,
                    y: startCenter.y + (endCenter.y - startCenter.y) * collapseProgress
                )
                let scaleValue = max(CGFloat(0.6), 1 - 0.35 * collapseProgress)
                let opacityValue = max(0, 1 - 0.9 * collapseProgress)

                MergeAnimatingCard(error: context.topItem)
                    .frame(width: context.topFrame.width, height: context.topFrame.height)
                    .position(x: currentCenter.x, y: currentCenter.y)
                    .scaleEffect(scaleValue)
                    .opacity(opacityValue)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct MergeAnimatingCard: View {
    let error: ErrorItem

    var body: some View {
        ErrorItemRow(
            err: error,
            selected: false,
            onSave: nil,
            isMergeMode: false,
            isMergeCandidate: false,
            isSelectedForMerge: false,
            isSelectionDisabled: false,
            isMerging: false,
            frameInResults: nil,
            pinchProgress: 0,
            pinchCentroid: .zero,
            isNewlyMerged: false
        )
    }
}

struct ErrorRowFramePreferenceKey: PreferenceKey {
    static var defaultValue: [UUID: CGRect] = [:]

    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { _, new in new }
    }
}
