import SwiftUI
import UIKit

/// Controls highlight layer animations and transitions for morphing annotated text
final class HighlightAnimationController {

    // MARK: - State Management

    /// Cache for highlight rects by ID (from/to states)
    private var fromRects: [UUID: [CGRect]] = [:]
    private var toRects: [UUID: [CGRect]] = [:]

    /// Color mapping for highlight IDs
    private var fromColors: [UUID: UIColor] = [:]
    private var toColors: [UUID: UIColor] = [:]

    /// Highlight layers by ID for animation
    private var highlightLayers: [UUID: [CALayer]] = [:]

    /// Current display state
    private var currentShowingCorrected: Bool = false

    /// Reference to overlay view for layer management
    private weak var overlayView: UIView?

    // MARK: - Initialization

    init(overlayView: UIView) {
        self.overlayView = overlayView
    }

    // MARK: - State Updates

    /// Update cached rects and colors for animation
    func updateState(
        fromRects: [UUID: [CGRect]],
        toRects: [UUID: [CGRect]],
        fromColors: [UUID: UIColor],
        toColors: [UUID: UIColor],
        currentShowingCorrected: Bool
    ) {
        self.fromRects = fromRects
        self.toRects = toRects
        self.fromColors = fromColors
        self.toColors = toColors
        self.currentShowingCorrected = currentShowingCorrected
    }

    // MARK: - Animation Control

    /// Animate transition between original and corrected states
    func animateTransition(
        toCorrected: Bool,
        selectedID: UUID?,
        fromTextView: UITextView,
        toTextView: UITextView,
        onCompletion: @escaping (Bool) -> Void
    ) {
        AppLog.uiDebug("[HighlightAnimationController.animateTransition] toCorrected=\(toCorrected) current=\(currentShowingCorrected)")

        guard currentShowingCorrected != toCorrected else {
            layoutHighlightLayers(selectedID: selectedID, immediate: true)
            return
        }

        // Text crossfade + move/scale animation
        let duration: TimeInterval = 0.8
        let move: CGFloat = 12

        UIView.performWithoutAnimation {
            if toCorrected {
                // Entering: toTextView moves in; Leaving: fromTextView stays put and fades
                fromTextView.alpha = 1
                fromTextView.transform = .identity
                toTextView.alpha = 0
                toTextView.transform = CGAffineTransform(translationX: 0, y: move).scaledBy(x: 0.98, y: 0.98)
            } else {
                // Entering: fromTextView moves in; Leaving: toTextView stays put and fades
                toTextView.alpha = 1
                toTextView.transform = .identity
                fromTextView.alpha = 0
                fromTextView.transform = CGAffineTransform(translationX: 0, y: move).scaledBy(x: 0.98, y: 0.98)
            }
        }

        layoutHighlightLayers(selectedID: selectedID, immediate: false)

        let fadeDelay: TimeInterval = 0.04
        UIView.animateKeyframes(
            withDuration: duration,
            delay: 0,
            options: [.allowUserInteraction, .beginFromCurrentState, .calculationModeCubic],
            animations: {
                // Keyframe 1: entering view moves to identity + fades in
                UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) {
                    if toCorrected {
                        toTextView.alpha = 1
                        toTextView.transform = .identity
                    } else {
                        fromTextView.alpha = 1
                        fromTextView.transform = .identity
                    }
                }
                // Keyframe 2: small delay then fade out leaving view
                UIView.addKeyframe(withRelativeStartTime: max(0, fadeDelay / duration), relativeDuration: 1 - max(0, fadeDelay / duration)) {
                    if toCorrected {
                        fromTextView.alpha = 0
                        fromTextView.transform = .identity
                    } else {
                        toTextView.alpha = 0
                        toTextView.transform = .identity
                    }
                }
            },
            completion: { finished in
                self.currentShowingCorrected = toCorrected
                onCompletion(finished)
            }
        )

        // Animate highlight layer frames and alpha
        applyHighlightTargets(toCorrected: toCorrected, selectedID: selectedID, duration: duration)
    }

    /// Layout highlight layers for current state
    func layoutHighlightLayers(selectedID: UUID?, immediate: Bool) {
        guard let overlayView = overlayView else { return }

        // Remove existing layers and rebuild for a clean baseline
        overlayView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        highlightLayers.removeAll()

        let rectsByID = currentShowingCorrected ? toRects : fromRects

        for (id, rects) in rectsByID {
            let layers = rects.map { rect -> CALayer in
                let layer = CALayer()
                layer.frame = rect
                layer.cornerRadius = DS.Component.HighlightLayer.cornerRadius
                layer.masksToBounds = true
                let isSelected = (id == selectedID)
                let fill = highlightFillColor(for: colorFor(id: id), isSelected: isSelected)
                layer.backgroundColor = fill
                overlayView.layer.addSublayer(layer)
                return layer
            }
            highlightLayers[id] = layers
        }
    }

    // MARK: - Private Animation Methods

    private func applyHighlightTargets(toCorrected: Bool, selectedID: UUID?, duration: TimeInterval = 1.2) {
        // Determine mapping: match rects by index for ids present in both states
        let start = toCorrected ? fromRects : toRects
        let end = toCorrected ? toRects : fromRects

        guard let overlayView = overlayView else { return }

        // Build layers for any missing ids at start
        for (id, endRects) in end {
            if highlightLayers[id] == nil {
                // create layers at start position (same as end but alpha 0) to fade in
                let layers = endRects.map { rect -> CALayer in
                    let layer = CALayer()
                    layer.frame = rect
                    layer.cornerRadius = DS.Component.HighlightLayer.cornerRadius
                    let isSelected = (id == selectedID)
                    let fill = highlightFillColor(for: colorFor(id: id), isSelected: isSelected)
                    layer.backgroundColor = fill
                    layer.opacity = 0
                    overlayView.layer.addSublayer(layer)
                    return layer
                }
                highlightLayers[id] = layers
            }
        }

        // Animate each id group
        for (id, layers) in highlightLayers {
            let fromRects = start[id] ?? []
            let toRects = end[id] ?? []
            let count = min(layers.count, min(fromRects.count, toRects.count))

            // Update color/alpha for selection state (constant during animation)
            let isSelected = (id == selectedID)
            let fill = highlightFillColor(for: colorFor(id: id), isSelected: isSelected)

            // matched pairs move
            if count > 0 {
                for i in 0..<count {
                    let layer = layers[i]
                    layer.backgroundColor = fill
                    let target = toRects[i]

                    // Explicit animations for position and bounds to ensure visible motion
                    let posAnim = CABasicAnimation(keyPath: "position")
                    posAnim.fromValue = NSValue(cgPoint: layer.position)
                    posAnim.toValue = NSValue(cgPoint: CGPoint(x: target.midX, y: target.midY))
                    posAnim.duration = duration
                    posAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

                    let boundsAnim = CABasicAnimation(keyPath: "bounds")
                    boundsAnim.fromValue = NSValue(cgRect: layer.bounds)
                    boundsAnim.toValue = NSValue(cgRect: CGRect(origin: .zero, size: target.size))
                    boundsAnim.duration = duration
                    boundsAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

                    layer.position = CGPoint(x: target.midX, y: target.midY)
                    layer.bounds = CGRect(origin: .zero, size: target.size)
                    layer.opacity = 1
                    layer.add(posAnim, forKey: "pos")
                    layer.add(boundsAnim, forKey: "bounds")
                }
            }

            // extra start rects fade out
            if fromRects.count > count {
                for i in count..<fromRects.count {
                    if i < layers.count {
                        let layer = layers[i]
                        layer.backgroundColor = fill
                        // fade out
                        let fade = CABasicAnimation(keyPath: "opacity")
                        fade.fromValue = layer.opacity
                        fade.toValue = 0
                        fade.duration = duration
                        fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        layer.opacity = 0
                        layer.add(fade, forKey: "fadeOut")
                    }
                }
            }

            // extra end rects fade in (create new layers if needed)
            if toRects.count > count {
                for i in count..<toRects.count {
                    let layer: CALayer
                    if i < layers.count {
                        layer = layers[i]
                    } else {
                        layer = CALayer()
                        overlayView.layer.addSublayer(layer)
                        highlightLayers[id]?.append(layer)
                    }
                    layer.cornerRadius = DS.Component.HighlightLayer.cornerRadius
                    layer.backgroundColor = fill
                    let target = toRects[i]
                    layer.position = CGPoint(x: target.midX, y: target.midY)
                    layer.bounds = CGRect(origin: .zero, size: target.size)
                    // fade in
                    let fade = CABasicAnimation(keyPath: "opacity")
                    fade.fromValue = 0
                    fade.toValue = 1
                    fade.duration = duration
                    fade.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    layer.opacity = 1
                    layer.add(fade, forKey: "fadeIn")
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func highlightFillColor(for candidate: UIColor?, isSelected: Bool) -> CGColor {
        let base = candidate ?? UIColor(DS.Palette.primary)
        let opacity = isSelected ? DS.Opacity.highlightActive : DS.Opacity.highlightInactive
        return base.withAlphaComponent(opacity).cgColor
    }

    private func colorFor(id: UUID) -> UIColor? {
        if currentShowingCorrected {
            if let c = toColors[id] ?? fromColors[id] { return c }
        } else {
            if let c = fromColors[id] ?? toColors[id] { return c }
        }
        return nil
    }
}
