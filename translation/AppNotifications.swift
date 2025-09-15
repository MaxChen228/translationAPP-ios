import Foundation

extension Notification.Name {
    static let correctionCompleted = Notification.Name("correctionCompleted")
}

enum AppEventKeys {
    static let workspaceID = "workspaceID"
    static let score = "score"
    static let errors = "errors"
}

