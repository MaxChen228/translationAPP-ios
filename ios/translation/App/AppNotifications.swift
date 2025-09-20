import Foundation

extension Notification.Name {
    static let correctionCompleted = Notification.Name("correctionCompleted")
    static let correctionFailed = Notification.Name("correctionFailed")
    static let ttsError = Notification.Name("ttsError")
}

enum AppEventKeys {
    static let workspaceID = "workspaceID"
    static let score = "score"
    static let errors = "errors"
    static let error = "error"
}
