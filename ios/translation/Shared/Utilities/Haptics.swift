import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum Haptics {
    static func success() {
        #if os(iOS)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.success)
        #endif
    }
    static func warning() {
        #if os(iOS)
        let gen = UINotificationFeedbackGenerator()
        gen.notificationOccurred(.warning)
        #endif
    }
    static func lightTick() {
        #if os(iOS)
        let gen = UIImpactFeedbackGenerator(style: .light)
        gen.impactOccurred()
        #endif
    }

    static func light() {
        lightTick()
    }

    static func medium() {
        #if os(iOS)
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.impactOccurred()
        #endif
    }
}
