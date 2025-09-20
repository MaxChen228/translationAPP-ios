import OSLog
import Foundation

enum AppLog {
    private static let subsystem: String = {
        Bundle.main.bundleIdentifier ?? "translation"
    }()
    static let ai = Logger(subsystem: subsystem, category: "AI")
    static let ui = Logger(subsystem: subsystem, category: "UI")
    static let flashcards = Logger(subsystem: subsystem, category: "Flashcards")

    // Convenience: also mirror logs to Xcode console via print in DEBUG so you always see them
    @inline(__always)
    static func aiDebug(_ message: String) {
        ai.debug("\(message, privacy: .public)")
        #if DEBUG
        print("[AI][debug] \(message)")
        #endif
    }

    @inline(__always)
    static func aiInfo(_ message: String) {
        ai.info("\(message, privacy: .public)")
        #if DEBUG
        print("[AI][info] \(message)")
        #endif
    }

    @inline(__always)
    static func aiError(_ message: String) {
        ai.error("\(message, privacy: .public)")
        #if DEBUG
        print("[AI][error] \(message)")
        #endif
    }
}

extension AppLog {
    @inline(__always)
    static func uiDebug(_ message: String) {
        ui.debug("\(message, privacy: .public)")
        #if DEBUG
        print("[UI][debug] \(message)")
        #endif
    }

    @inline(__always)
    static func uiInfo(_ message: String) {
        ui.info("\(message, privacy: .public)")
        #if DEBUG
        print("[UI][info] \(message)")
        #endif
    }

    @inline(__always)
    static func uiError(_ message: String) {
        ui.error("\(message, privacy: .public)")
        #if DEBUG
        print("[UI][error] \(message)")
        #endif
    }
}

extension AppLog {
    @inline(__always)
    static func flashcardsDebug(_ message: String) {
        flashcards.debug("\(message, privacy: .public)")
        #if DEBUG
        print("[Flashcards][debug] \(message)")
        #endif
    }

    @inline(__always)
    static func flashcardsInfo(_ message: String) {
        flashcards.info("\(message, privacy: .public)")
        #if DEBUG
        print("[Flashcards][info] \(message)")
        #endif
    }

    @inline(__always)
    static func flashcardsError(_ message: String) {
        flashcards.error("\(message, privacy: .public)")
        #if DEBUG
        print("[Flashcards][error] \(message)")
        #endif
    }
}
