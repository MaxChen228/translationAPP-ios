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
        static let sm: CGFloat = 10
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
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
    }

    enum Shadow {
        static let card = ShadowStyle(color: Color.black.opacity(0.06), radius: 12, y: 6)
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
        static var scoreGradient: LinearGradient {
            LinearGradient(colors: [Brand.scheme.cornhusk, Brand.scheme.peachQuartz, Brand.scheme.provence, Brand.scheme.classicBlue], startPoint: .leading, endPoint: .trailing)
        }
        static var primaryGradient: LinearGradient {
            LinearGradient(colors: [Brand.scheme.provence, Brand.scheme.classicBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
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

        // Serif = Songti
        static let serifTitle = customOrSystemCandidates(FontFamily.songtiCandidates, size: 22, relativeTo: .title2)
        static let serifBody = customOrSystemCandidates(FontFamily.songtiCandidates, size: 17, relativeTo: .body)

        // Monospace-like usage still use Avenir per requirement
        static let mono = customOrSystemCandidates(FontFamily.avenirCandidates, size: 15, relativeTo: .callout)
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

extension View {
    func dsCardShadow() -> some View {
        shadow(color: DS.Shadow.card.color, radius: DS.Shadow.card.radius, x: 0, y: DS.Shadow.card.y)
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
