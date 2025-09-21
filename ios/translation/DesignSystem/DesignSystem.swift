import SwiftUI
import UIKit

// Minimal, extensible design tokens for consistent UI
enum DS {
    enum Metrics {
        // Base hairline thickness; slightly thicker for better visibility on 3x
        // Previously: 1 / UIScreen.main.scale (~0.33pt on 3x). Now ensure >= 0.5pt.
        static var hairline: CGFloat { max(1 / UIScreen.main.scale, 0.5) }
    }
    enum Spacing {
        static let xs: CGFloat = 6
        static let xs2: CGFloat = 8
        static let sm: CGFloat = 10
        static let sm2: CGFloat = 12
        static let md2: CGFloat = 14
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }

    // Standardized border widths so we avoid magic numbers
    enum BorderWidth {
        // Hairline should reflect device pixel ratio; reuse Metrics.hairline
        static var hairline: CGFloat { DS.Metrics.hairline }
        // Thin cosmetic borders (chips, badges)
        static let thin: CGFloat = 0.8
        // Regular 1pt borders (inputs, buttons, outlines)
        static let regular: CGFloat = 1.0
    }

    enum Radius {
        static let xs: CGFloat = 6
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let md2: CGFloat = 14
        static let lg: CGFloat = 16
    }

    enum Shadow {
        static let card = ShadowStyle(color: Color.black.opacity(0.06), radius: 12, y: 6)
        static let overlay = ShadowStyle(color: Color.black.opacity(0.1), radius: 10, y: 6)
    }

    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat = 0
        let y: CGFloat
    }

    // Centralized animation tokens to keep motion consistent
    enum AnimationToken {
        // Snappy movement for small layout changes (e.g., reordering)
        static var snappy: Animation { .interactiveSpring(response: 0.26, dampingFraction: 0.86) }
        // Bouncy card-like motion (e.g., flipping, card return)
        static var bouncy: Animation { .spring(response: 0.42, dampingFraction: 0.85) }
        // Quick fade/slide for subtle UI state transitions
        static var subtle: Animation { .easeInOut(duration: 0.2) }
        // Flip timing
        static var flip: Animation { .easeInOut(duration: 0.32) }
        // Reorder list/grid items
        static var reorder: Animation { snappy }
        // Toss a card out quickly
        static var tossOut: Animation { .easeOut(duration: 0.18) }
        // Progress indicators (rings/bars)
        static var progress: Animation { .easeInOut(duration: 0.25) }
    }

    // Brand color scheme (easy to swap for theming)
    struct BrandScheme {
        let classicBlue: Color   // 19-4052
        let provence: Color      // 16-4032
        let babyBlue: Color      // 13-4308
        let monument: Color      // 17-4405
        let stucco: Color        // 16-1412
        let peachQuartz: Color   // 13-1125
        let cornhusk: Color      // 12-0714
    }

    // Opacity tokens (avoid magic numbers sprinkled around)
    enum Opacity {
        static let fill: Double = 0.12      // chip/card subtle fills
        static let hairline: Double = 0.18  // hairline borders
        static let border: Double = 0.35    // default outlines/separators
        static let strong: Double = 0.45    // emphasized outlines/highlight
        static let muted: Double = 0.60     // subdued foregrounds/status
        static let accentLight: Double = 0.28 // accent separators/light tints
    }


    enum Brand {
        // Convert hex like "0F4C81" to Color
        private static func hex(_ hex: String) -> Color {
            var hex = hex
            if hex.hasPrefix("#") { hex.removeFirst() }
            let scanner = Scanner(string: hex)
            var rgb: UInt64 = 0
            scanner.scanHexInt64(&rgb)
            let r = Double((rgb >> 16) & 0xFF) / 255.0
            let g = Double((rgb >> 8) & 0xFF) / 255.0
            let b = Double(rgb & 0xFF) / 255.0
            return Color(red: r, green: g, blue: b)
        }

        static var scheme: BrandScheme = BrandScheme(
            classicBlue: hex("0F4C81"),
            provence:    hex("5A7DB1"),
            babyBlue:    hex("B0C4D8"),
            monument:    hex("7E868C"),
            stucco:      hex("A48774"),
            peachQuartz: hex("F5B095"),
            cornhusk:    hex("EFD5A7")
        )

        static func set(_ new: BrandScheme) { scheme = new }
    }

    enum Palette {
        static var surface: Color { Color(.secondarySystemBackground) }
        static var surfaceAlt: Color { Color(UIColor { tc in
            tc.userInterfaceStyle == .dark ? UIColor.secondarySystemBackground.withAlphaComponent(0.6) : UIColor.systemGray6
        }) }
        static var background: Color { Color(.systemBackground) }
        static var border: Color { Color(.separator) }
        static var primary: Color { Brand.scheme.classicBlue }
        static var subdued: Color { .secondary }
        // Foreground on primary surfaces (filled buttons/icons)
        static var onPrimary: Color { Color.white }
        // Neutral/chrome color
        static var neutral: Color { Color.gray }
        // Tracks and hairlines
        static var track: Color { Color.gray.opacity(0.2) }
        static var trackHairline: Color { Color.gray.opacity(DS.Opacity.hairline) }
        // Scrim overlays
        static var scrim: Color { Color.black.opacity(0.12) }
        // Semantic status colors (custom brand mapping)
        // success = #A8B5A2, warning = #D18E73
        static var success: Color { Color(red: 168/255.0, green: 181/255.0, blue: 162/255.0) }
        static var warning: Color { Color(red: 209/255.0, green: 142/255.0, blue: 115/255.0) }
        static var caution: Color { Color.yellow }
        static var danger: Color { Color.red }
        static var scoreGradient: LinearGradient {
            LinearGradient(colors: [Brand.scheme.cornhusk, Brand.scheme.peachQuartz, Brand.scheme.provence, Brand.scheme.classicBlue], startPoint: .leading, endPoint: .trailing)
        }
        static var primaryGradient: LinearGradient {
            LinearGradient(colors: [Brand.scheme.provence, Brand.scheme.classicBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        static var scoreAngular: AngularGradient {
            AngularGradient(gradient: Gradient(colors: [success, caution, warning, danger]), center: .center)
        }

        static func scoreColor(for score: Double) -> Color {
            switch score {
            case 90...: return success
            case 70..<90: return warning
            case 50..<70: return caution
            default: return danger
            }
        }
    }

    enum FontFamily {
        static let songtiCandidates = [
            "Songti SC",
            "STSongti-SC-Regular",
            "STSongti-SC-Light",
            "STSongti-SC-Medium",
            "STSongti-SC-Bold",
            "Songti" // bundled custom name fallback
        ]
        static let avenirCandidates = [
            "Avenir Next",
            "AvenirNext-Regular",
            "AvenirNext-Medium",
            "Avenir-Book",
            "Avenir-Roman",
            "Avenir" // family fallback
        ]
    }

    enum Font {
        private static func customOrSystemCandidates(_ names: [String], size: CGFloat, relativeTo style: SwiftUI.Font.TextStyle) -> SwiftUI.Font {
            for name in names {
                if UIFont(name: name, size: size) != nil {
                    return .custom(name, size: size, relativeTo: style)
                }
            }
            return .system(style)
        }

        // Normal (sans) = Avenir
        static let display = customOrSystemCandidates(FontFamily.avenirCandidates, size: 32, relativeTo: .largeTitle)
        static let title = customOrSystemCandidates(FontFamily.avenirCandidates, size: 22, relativeTo: .title2)
        static let section = customOrSystemCandidates(FontFamily.avenirCandidates, size: 17, relativeTo: .headline)
        static let body = customOrSystemCandidates(FontFamily.avenirCandidates, size: 17, relativeTo: .body)
        static let bodyEmph = customOrSystemCandidates(FontFamily.avenirCandidates, size: 17, relativeTo: .body)
        static let caption = customOrSystemCandidates(FontFamily.avenirCandidates, size: 12, relativeTo: .caption2)
        static let labelMd = customOrSystemCandidates(FontFamily.avenirCandidates, size: 14, relativeTo: .footnote)
        static let labelSm = customOrSystemCandidates(FontFamily.avenirCandidates, size: 13, relativeTo: .footnote)

        // Serif = Songti
        static let serifTitle = customOrSystemCandidates(FontFamily.songtiCandidates, size: 22, relativeTo: .title2)
        static let serifBody = customOrSystemCandidates(FontFamily.songtiCandidates, size: 17, relativeTo: .body)

        // Monospace-like usage still use Avenir per requirement
        static let mono = customOrSystemCandidates(FontFamily.avenirCandidates, size: 15, relativeTo: .callout)
        // Additional tokens for small labels and monospace snippets
        static let monoSmall: SwiftUI.Font = .system(size: 12, design: .monospaced)
        static let tiny: SwiftUI.Font = .system(size: 9)
    }

    enum IconSize {
        static let chevronSm: CGFloat = 13
        static let chevronMd: CGFloat = 14
        static let calendarCell: CGFloat = 40
        static let activityIndicatorBase: CGFloat = 4

        // 卡片與組件圖標尺寸
        static let cardIcon: CGFloat = 28           // 卡片標題圖標寬度
        static let playButton: CGFloat = 40         // 播放按鈕尺寸
        static let controlButton: CGFloat = 32      // 控制按鈕尺寸
        static let toolbarIcon: CGFloat = 44        // 工具列按鈕尺寸
        static let avatar: CGFloat = 72             // 頭像尺寸
        static let scoreRing: CGFloat = 96          // 分數環形圖尺寸

        // 指示器與分隔線
        static let indicatorSmall: CGFloat = 6      // 小指示器
        static let indicatorMedium: CGFloat = 8     // 中指示器
        static let dividerThin: CGFloat = 3         // 細分隔線寬度
        static let progressBar: CGFloat = 10        // 進度條高度

        // 佈局相關寬度
        static let entryCardWidth: CGFloat = 220    // 入口卡片寬度
        static let settingsSlider: CGFloat = 160    // 設定滑桿寬度
    }

    enum ButtonSize {
        static let compact: CGFloat = 64            // 緊湊按鈕寬度
        static let small: CGFloat = 92              // 小按鈕寬度
        static let medium: CGFloat = 100            // 中按鈕寬度
        static let standard: CGFloat = 120          // 標準按鈕寬度
    }

    enum CardSize {
        static let minHeightStandard: CGFloat = 104 // 標準卡片最小高度
        static let minHeightCompact: CGFloat = 96   // 緊湊卡片最小高度
        static let minHeightLarge: CGFloat = 240    // 大卡片最小高度
        static let dividerHeight: CGFloat = 42      // 分隔器高度
    }

    enum CalendarMetrics {
        static func activityIndicatorSize(for count: Int) -> CGFloat {
            switch count {
            case 1: return DS.IconSize.activityIndicatorBase
            case 2...5: return DS.IconSize.activityIndicatorBase + 1
            case 6...10: return DS.IconSize.activityIndicatorBase + 2
            default: return DS.IconSize.activityIndicatorBase + 3
            }
        }
    }

    // UIKit font helpers for measurement/layout parity
    enum DSUIFont {
        private static func firstExisting(_ names: [String], size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
            for name in names {
                if let f = UIFont(name: name, size: size) { return f }
            }
            return UIFont.systemFont(ofSize: size, weight: weight)
        }
        static func serifBody() -> UIFont {
            return firstExisting(FontFamily.songtiCandidates, size: 17)
        }
        static func serifBodyLarge() -> UIFont {
            return firstExisting(FontFamily.songtiCandidates, size: 19)
        }
        static func serifBodyXL() -> UIFont {
            return firstExisting(FontFamily.songtiCandidates, size: 22)
        }
        static func serifLargeTitle() -> UIFont {
            // Match UINavigationBar large title scale
            return firstExisting(FontFamily.songtiCandidates, size: 34, weight: .bold)
        }
        static func body() -> UIFont {
            return firstExisting(FontFamily.avenirCandidates, size: 17)
        }
    }
}

// Centralized transition tokens to keep enter/exit effects consistent
enum DSTransition {
    static var slideTrailingFade: AnyTransition {
        .move(edge: .trailing).combined(with: .opacity)
    }
    static var fade: AnyTransition { .opacity }
    static var cardExpand: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }
}

// MARK: - Components

struct DSQuickActionIconButton: View {
    enum Shape {
        case roundedRect
        case circle
    }

    enum Style {
        case tinted
        case outline
        case filled
    }

    var systemName: String
    var labelKey: LocalizedStringKey
    var action: () -> Void
    var shape: Shape = .roundedRect
    var style: Style = .tinted
    var size: CGFloat = 36

    var body: some View {
        Button(action: action) {
            DSQuickActionIconGlyph(systemName: systemName, shape: shape, style: style, size: size)
        }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: DSQuickActionIconGlyph.cornerRadius(for: shape, size: size), style: .continuous))
            .accessibilityLabel(Text(labelKey))
    }
}

struct DSQuickActionIconGlyph: View {
    var systemName: String
    var shape: DSQuickActionIconButton.Shape = .roundedRect
    var style: DSQuickActionIconButton.Style = .tinted
    var size: CGFloat = 36

    private var cornerRadius: CGFloat { Self.cornerRadius(for: shape, size: size) }

    private var foregroundColor: Color {
        switch style {
        case .filled: return DS.Palette.onPrimary
        case .tinted, .outline: return DS.Palette.primary
        }
    }

    private var backgroundStyle: AnyShapeStyle {
        switch style {
        case .tinted:
            return AnyShapeStyle(DS.Palette.surface.opacity(DS.Opacity.fill))
        case .outline:
            return AnyShapeStyle(Color.clear)
        case .filled:
            if shape == .circle {
                return AnyShapeStyle(DS.Palette.primaryGradient)
            } else {
                return AnyShapeStyle(DS.Palette.primary)
            }
        }
    }

    private var borderColor: Color? {
        switch style {
        case .tinted:
            return DS.Palette.border.opacity(DS.Opacity.border)
        case .outline:
            return DS.Palette.primary.opacity(0.55)
        case .filled:
            return nil
        }
    }

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(foregroundColor)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(backgroundStyle)
            )
            .overlay(
                Group {
                    if let borderColor {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(borderColor, lineWidth: DS.BorderWidth.regular)
                    }
                }
            )
    }

    static func cornerRadius(for shape: DSQuickActionIconButton.Shape, size: CGFloat) -> CGFloat {
        switch shape {
        case .roundedRect: return DS.Radius.md
        case .circle: return size / 2
        }
    }
}

extension View {
    func dsCardShadow() -> some View {
        shadow(color: DS.Shadow.card.color, radius: DS.Shadow.card.radius, x: 0, y: DS.Shadow.card.y)
    }
}

// MARK: - Motion helpers (respect Reduce Motion)
enum DSMotion {
    static func run(_ animation: Animation, _ body: () -> Void) {
        #if os(iOS)
        if UIAccessibility.isReduceMotionEnabled { body(); return }
        #endif
        withAnimation(animation, body)
    }
}

extension View {
    @ViewBuilder
    func dsAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        #if os(iOS)
        if UIAccessibility.isReduceMotionEnabled { self.animation(nil, value: value) }
        else { self.animation(animation, value: value) }
        #else
        self.animation(animation, value: value)
        #endif
    }
}

struct DSTypography: ViewModifier {
    var font: SwiftUI.Font
    var lineSpacing: CGFloat = 4
    var tracking: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .font(font)
            .tracking(tracking)
            .lineSpacing(lineSpacing)
    }
}

extension View {
    func dsType(_ font: SwiftUI.Font, lineSpacing: CGFloat = 4, tracking: CGFloat = 0) -> some View {
        modifier(DSTypography(font: font, lineSpacing: lineSpacing, tracking: tracking))
    }
}
