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

    // Animation controller for highlight transitions
    private lazy var animationController = HighlightAnimationController(overlayView: overlayView)

    // Caches for highlight rects by ID
    private var fromRects: [UUID: [CGRect]] = [:]
    private var toRects: [UUID: [CGRect]] = [:]
    private var fromColors: [UUID: UIColor] = [:]
    private var toColors: [UUID: UIColor] = [:]
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
            updateAnimationControllerState()
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
                updateAnimationControllerState()
                animationController.animateTransition(
                    toCorrected: showingCorrected,
                    selectedID: selectedID,
                    fromTextView: fromTextView,
                    toTextView: toTextView
                ) { _ in
                    self.currentShowingCorrected = showingCorrected
                }
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
                updateAnimationControllerState()
                animationController.layoutHighlightLayers(selectedID: selectedID, immediate: true)
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
                updateAnimationControllerState()
                animationController.layoutHighlightLayers(selectedID: lastSelectedID, immediate: true)
                needsRectComputeOnLayout = false
                if pendingAnimateSwitch {
                    let target = pendingTargetCorrected
                    pendingAnimateSwitch = false
                    animationController.animateTransition(
                        toCorrected: target,
                        selectedID: lastSelectedID,
                        fromTextView: fromTextView,
                        toTextView: toTextView
                    ) { _ in
                        self.currentShowingCorrected = target
                    }
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

    // MARK: - Animation Controller Integration

    /// Update animation controller with current state
    private func updateAnimationControllerState() {
        animationController.updateState(
            fromRects: fromRects,
            toRects: toRects,
            fromColors: fromColors,
            toColors: toColors,
            currentShowingCorrected: currentShowingCorrected
        )
    }

}

private extension NSAttributedString {
    func with(font: UIFont, paragraph: NSMutableParagraphStyle) -> NSAttributedString {
        let m = NSMutableAttributedString(attributedString: self)
        m.addAttributes([.font: font, .paragraphStyle: paragraph], range: NSRange(location: 0, length: m.length))
        return m
    }
}
