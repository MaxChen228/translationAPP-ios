import SwiftUI
import UIKit

// Renders text with filled rectangle highlights and supports a smooth
// crossfade + slight move transition between two texts while moving
// highlights to their target positions. No third-party dependencies.
struct MorphingAnnotatedText: UIViewRepresentable {
    var originalText: String
    var correctedText: String
    var originalHighlights: [Highlight]
    var correctedHighlights: [Highlight]
    var selectedID: UUID?
    var isShowingCorrected: Bool

    // Typography
    var font: UIFont = DS.DSUIFont.serifBodyXL()
    var lineSpacing: CGFloat = 8

    func makeCoordinator() -> Coordinator { Coordinator() }

    // Accurate sizing to avoid oversized blank area beneath text
    @available(iOS 16.0, *)
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: MTContainerView, context: Context) -> CGSize {
        let width = max(1, Int((proposal.width ?? UIScreen.main.bounds.width)))
        // Measure without depending on current UITextView state to avoid 0 height.
        let measured = TextMeasurement.measureHeight(original: originalText,
                                                   corrected: correctedText,
                                                   font: font,
                                                   lineSpacing: lineSpacing,
                                                   width: CGFloat(width))
        AppLog.uiDebug("[sizeThatFits] proposedW=\(width) measuredH=\(measured)")
        return CGSize(width: CGFloat(width), height: measured)
    }


    func makeUIView(context: Context) -> MTContainerView {
        let view = MTContainerView()
        view.configure(font: font, lineSpacing: lineSpacing)
        view.setContent(
            original: originalText,
            corrected: correctedText,
            originalHighlights: originalHighlights,
            correctedHighlights: correctedHighlights,
            selectedID: selectedID,
            showingCorrected: isShowingCorrected,
            animated: false
        )
        context.coordinator.lastIsShowingCorrected = isShowingCorrected
        return view
    }

    func updateUIView(_ uiView: MTContainerView, context: Context) {
        let changedMode = (context.coordinator.lastIsShowingCorrected != isShowingCorrected)
        uiView.configure(font: font, lineSpacing: lineSpacing)
        uiView.setContent(
            original: originalText,
            corrected: correctedText,
            originalHighlights: originalHighlights,
            correctedHighlights: correctedHighlights,
            selectedID: selectedID,
            showingCorrected: isShowingCorrected,
            animated: changedMode
        )
        context.coordinator.lastIsShowingCorrected = isShowingCorrected
    }

    static func dismantleUIView(_ uiView: MTContainerView, coordinator: Coordinator) {}

    class Coordinator {
        var lastIsShowingCorrected: Bool = false
    }
}

// MARK: - UIKit container

final class MTContainerView: UIView {
    private let fromTextView = UITextView()
    private let toTextView = UITextView()
    private let overlayView = UIView()

    private var currentShowingCorrected: Bool = false
    private var paraStyle: NSMutableParagraphStyle = {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = 6
        return p
    }()

    // Caches for highlight rects by ID
    private var fromRects: [UUID: [CGRect]] = [:]
    private var toRects: [UUID: [CGRect]] = [:]
    private var fromColors: [UUID: UIColor] = [:]
    private var toColors: [UUID: UIColor] = [:]

    // Keep layers so we can animate frames
    private var highlightLayers: [UUID: [CALayer]] = [:]
    // Track last content for size-change recompute
    private var lastOriginalText: String = ""
    private var lastCorrectedText: String = ""
    private var lastOriginalHighlights: [Highlight] = []
    private var lastCorrectedHighlights: [Highlight] = []
    private var lastSelectedID: UUID? = nil
    private var lastSize: CGSize = .zero
    private var needsRectComputeOnLayout: Bool = false
    private var pendingAnimateSwitch: Bool = false
    private var pendingTargetCorrected: Bool = false

    override init(frame: CGRect) {
        super.init(frame: frame)

        isOpaque = false

        for tv in [fromTextView, toTextView] {
            tv.isEditable = false
            tv.isScrollEnabled = true // top-align content to avoid vertical centering offset
            tv.isUserInteractionEnabled = false
            tv.backgroundColor = .clear
            tv.textContainerInset = .zero
            tv.textContainer.lineFragmentPadding = 0
            tv.adjustsFontForContentSizeCategory = true
            addSubview(tv)
        }

        overlayView.isUserInteractionEnabled = false
        overlayView.backgroundColor = .clear
        overlayView.clipsToBounds = true
        insertSubview(overlayView, at: 0) // keep highlights behind text
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(font: UIFont, lineSpacing: CGFloat) {
        let p = NSMutableParagraphStyle()
        p.lineSpacing = lineSpacing
        paraStyle = p
        fromTextView.font = font
        toTextView.font = font
        fromTextView.attributedText = fromTextView.attributedText?.with(font: font, paragraph: p)
        toTextView.attributedText = toTextView.attributedText?.with(font: font, paragraph: p)
        setNeedsLayout()
    }

    func setContent(
        original: String,
        corrected: String,
        originalHighlights: [Highlight],
        correctedHighlights: [Highlight],
        selectedID: UUID?,
        showingCorrected: Bool,
        animated: Bool
    ) {
        // cache for later recompute when size changes
        lastOriginalText = original
        lastCorrectedText = corrected
        lastOriginalHighlights = originalHighlights
        lastCorrectedHighlights = correctedHighlights
        lastSelectedID = selectedID
        AppLog.uiDebug("[setContent] corrected=\(showingCorrected) animated=\(animated) origHL=\(originalHighlights.count) corrHL=\(correctedHighlights.count)")
        // Prepare attributed strings
        let fromAttr = NSAttributedString(
            string: original,
            attributes: [
                .font: fromTextView.font ?? DS.DSUIFont.serifBody(),
                .paragraphStyle: paraStyle,
                .foregroundColor: UIColor.label
            ]
        )
        let toAttr = NSAttributedString(
            string: corrected,
            attributes: [
                .font: toTextView.font ?? DS.DSUIFont.serifBody(),
                .paragraphStyle: paraStyle,
                .foregroundColor: UIColor.label
            ]
        )

        fromTextView.attributedText = fromAttr
        toTextView.attributedText = toAttr

        // Layout to compute rects with the current width
        setNeedsLayout()
        layoutIfNeeded()

        // Map colors per highlight id (independent of geometry)
        fromColors = TextMeasurement.colorsMap(for: originalHighlights)
        toColors = TextMeasurement.colorsMap(for: correctedHighlights)

        // If size is not yet valid, defer rect computation and animation to layoutSubviews
        if bounds.width <= 0 || bounds.height <= 0 {
            needsRectComputeOnLayout = true
            if animated { pendingAnimateSwitch = true; pendingTargetCorrected = showingCorrected }
        } else {
            fromRects = TextMeasurement.computeRects(in: fromTextView, text: original, highlights: originalHighlights)
            toRects = TextMeasurement.computeRects(in: toTextView, text: corrected, highlights: correctedHighlights)
        }

        // Ensure subviews layering: keep overlay behind
        sendSubviewToBack(overlayView)

        // Configure visibility
        if animated {
            // Keep baseline as currentShowingCorrected so animateTransition detects change
            fromTextView.alpha = currentShowingCorrected ? 0 : 1
            toTextView.alpha = currentShowingCorrected ? 1 : 0
            fromTextView.transform = .identity
            toTextView.transform = .identity
            if !needsRectComputeOnLayout {
                animateTransition(toCorrected: showingCorrected, selectedID: selectedID)
            } else {
                pendingAnimateSwitch = true
                pendingTargetCorrected = showingCorrected
            }
        } else {
            currentShowingCorrected = showingCorrected
            fromTextView.alpha = showingCorrected ? 0 : 1
            toTextView.alpha = showingCorrected ? 1 : 0
            fromTextView.transform = .identity
            toTextView.transform = .identity
            if !needsRectComputeOnLayout {
                layoutHighlightLayers(selectedID: selectedID, immediate: true)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let bounds = self.bounds
        fromTextView.frame = bounds
        toTextView.frame = bounds
        overlayView.frame = bounds
        AppLog.uiDebug("[layout] bounds=\(bounds.size) fromContentSize=\(fromTextView.contentSize) toContentSize=\(toTextView.contentSize)")
        if lastSize != bounds.size || needsRectComputeOnLayout {
            lastSize = bounds.size
            invalidateIntrinsicContentSize()
            if bounds.width > 0 && bounds.height > 0 {
                // recompute rects for final width
                fromRects = TextMeasurement.computeRects(in: fromTextView, text: lastOriginalText, highlights: lastOriginalHighlights)
                toRects = TextMeasurement.computeRects(in: toTextView, text: lastCorrectedText, highlights: lastCorrectedHighlights)
                layoutHighlightLayers(selectedID: lastSelectedID, immediate: true)
                needsRectComputeOnLayout = false
                if pendingAnimateSwitch {
                    let target = pendingTargetCorrected
                    pendingAnimateSwitch = false
                    animateTransition(toCorrected: target, selectedID: lastSelectedID)
                }
            }
        }
    }

    override var intrinsicContentSize: CGSize {
        let width = max(1, Int(self.bounds.width))
        let h = TextMeasurement.measureHeight(original: lastOriginalText,
                                             corrected: lastCorrectedText,
                                             font: fromTextView.font ?? DS.DSUIFont.serifBody(),
                                             lineSpacing: paraStyle.lineSpacing,
                                             width: CGFloat(width))
        AppLog.uiDebug("[intrinsic] width=\(width) height=\(h)")
        return CGSize(width: UIView.noIntrinsicMetric, height: h)
    }

    // Fitting height used by SwiftUI sizeThatFits
    func fittingHeight(forWidth width: CGFloat) -> CGFloat {
        let size = CGSize(width: width, height: .greatestFiniteMagnitude)
        fromTextView.textContainer.size = size
        toTextView.textContainer.size = size
        let h1 = fromTextView.sizeThatFits(size).height
        let h2 = toTextView.sizeThatFits(size).height
        return ceil(max(h1, h2))
    }

    // MARK: - Animation & Highlights

    private func animateTransition(toCorrected: Bool, selectedID: UUID?) {
        AppLog.uiDebug("[animate] toCorrected=\(toCorrected) current=\(currentShowingCorrected)")
        guard currentShowingCorrected != toCorrected else {
            layoutHighlightLayers(selectedID: selectedID, immediate: true)
            return
        }

        // Text crossfade + move/scale (faster)
        let duration: TimeInterval = 0.8
        let move: CGFloat = 12

        UIView.performWithoutAnimation {
            // Commit any pending layout to avoid first-frame jump
            self.layoutIfNeeded()
            if toCorrected {
                // Entering: toTextView moves in; Leaving: fromTextView stays put and fades
                self.fromTextView.alpha = 1
                self.fromTextView.transform = .identity
                self.toTextView.alpha = 0
                self.toTextView.transform = CGAffineTransform(translationX: 0, y: move).scaledBy(x: 0.98, y: 0.98)
            } else {
                // Entering: fromTextView moves in; Leaving: toTextView stays put and fades
                self.toTextView.alpha = 1
                self.toTextView.transform = .identity
                self.fromTextView.alpha = 0
                self.fromTextView.transform = CGAffineTransform(translationX: 0, y: move).scaledBy(x: 0.98, y: 0.98)
            }
        }

        layoutHighlightLayers(selectedID: selectedID, immediate: false)

        let fadeDelay: TimeInterval = 0.04
        UIView.animateKeyframes(withDuration: duration, delay: 0, options: [.allowUserInteraction, .beginFromCurrentState, .calculationModeCubic], animations: {
            // Keyframe 1: entering view moves to identity + fades in
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 1) {
                if toCorrected {
                    self.toTextView.alpha = 1
                    self.toTextView.transform = .identity
                } else {
                    self.fromTextView.alpha = 1
                    self.fromTextView.transform = .identity
                }
            }
            // Keyframe 2: small delay then fade out leaving view (kept at identity)
            UIView.addKeyframe(withRelativeStartTime: max(0, fadeDelay / duration), relativeDuration: 1 - max(0, fadeDelay / duration)) {
                if toCorrected {
                    self.fromTextView.alpha = 0
                    self.fromTextView.transform = .identity
                } else {
                    self.toTextView.alpha = 0
                    self.toTextView.transform = .identity
                }
            }
        }, completion: { _ in
            self.currentShowingCorrected = toCorrected
        })

        // Animate highlight layer frames and alpha with UIView animation block using .layoutIfNeeded equivalent
        applyHighlightTargets(toCorrected: toCorrected, selectedID: selectedID, duration: duration)
    }

    private func layoutHighlightLayers(selectedID: UUID?, immediate: Bool) {
        // Remove existing layers and rebuild for a clean baseline
        overlayView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        highlightLayers.removeAll()

        let rectsByID = currentShowingCorrected ? toRects : fromRects

        for (id, rects) in rectsByID {
            let layers = rects.map { rect -> CALayer in
                let layer = CALayer()
                layer.frame = rect
                layer.cornerRadius = 4
                layer.masksToBounds = true
                let isSelected = (id == selectedID)
                let color = colorFor(id: id) ?? UIColor(DS.Palette.primary)
                layer.backgroundColor = color.withAlphaComponent(isSelected ? 0.18 : 0.12).cgColor
                overlayView.layer.addSublayer(layer)
                return layer
            }
            highlightLayers[id] = layers
        }

        if immediate {
            return
        }
        // When preparing an animated transition, set start frames now; the animation call will set target frames.
    }

    private func applyHighlightTargets(toCorrected: Bool, selectedID: UUID?, duration: TimeInterval = 1.2) {
        // Determine mapping: match rects by index for ids present in both states.
        let start = toCorrected ? fromRects : toRects
        let end = toCorrected ? toRects : fromRects

        // Build layers for any missing ids at start
        for (id, endRects) in end {
            if highlightLayers[id] == nil {
                // create layers at start position (same as end but alpha 0) to fade in
                let layers = endRects.map { rect -> CALayer in
                    let layer = CALayer()
                    layer.frame = rect
                    layer.cornerRadius = 4
                    let isSelected = (id == selectedID)
                    let base = colorFor(id: id) ?? UIColor(DS.Palette.primary)
                    layer.backgroundColor = base.withAlphaComponent(isSelected ? 0.18 : 0.12).cgColor
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
            let base = colorFor(id: id) ?? UIColor(DS.Palette.primary)
            let fill = base.withAlphaComponent(isSelected ? 0.18 : 0.12).cgColor

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
                    layer.cornerRadius = 4
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


    // Intentionally no intrinsicContentSize; SwiftUI queries sizeThatFits for accurate height.


    private func colorFor(id: UUID) -> UIColor? {
        if currentShowingCorrected {
            if let c = toColors[id] ?? fromColors[id] { return c }
        } else {
            if let c = fromColors[id] ?? toColors[id] { return c }
        }
        // Fallback: search highlight arrays by id and use their type color
        if let h = (lastOriginalHighlights.first { $0.id == id } ?? lastCorrectedHighlights.first { $0.id == id }) {
            return UIColor(h.type.color)
        }
        return nil
    }
}

private extension NSAttributedString {
    func with(font: UIFont, paragraph: NSMutableParagraphStyle) -> NSAttributedString {
        let m = NSMutableAttributedString(attributedString: self)
        m.addAttributes([.font: font, .paragraphStyle: paragraph], range: NSRange(location: 0, length: m.length))
        return m
    }
}
