import Foundation
import BackgroundTasks
import UIKit

@MainActor
protocol ChatBackgroundCoordinating: AnyObject {
    var isBackgroundTaskActive: Bool { get }
    func configure(resumeHandler: @escaping @Sendable () async -> Void)
    func startBackgroundTaskIfNeeded()
    func endBackgroundTaskIfNeeded()
}

@MainActor
final class ChatBackgroundCoordinator: ChatBackgroundCoordinating {
    private(set) var isBackgroundTaskActive: Bool = false
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    private var resumeHandler: (() async -> Void)?
    private let taskIdentifier = "com.translation.chat.background"

    func configure(resumeHandler: @escaping @Sendable () async -> Void) {
        self.resumeHandler = resumeHandler
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            self.handleBackgroundTask(task: appRefreshTask)
        }
    }

    func startBackgroundTaskIfNeeded() {
        guard backgroundTaskID == .invalid else { return }
        backgroundTaskID = UIApplication.shared.beginBackgroundTask(withName: "ChatGeneration") { [weak self] in
            Task { @MainActor in
                self?.endBackgroundTaskIfNeeded()
            }
        }
        isBackgroundTaskActive = true
        AppLog.chatInfo("🔄 Started background task for chat")
    }

    func endBackgroundTaskIfNeeded() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
        isBackgroundTaskActive = false
        AppLog.chatInfo("✅ Ended background task for chat")
    }

    private func handleBackgroundTask(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        guard let resumeHandler else {
            task.setTaskCompleted(success: false)
            return
        }
        Task {
            await resumeHandler()
            task.setTaskCompleted(success: true)
        }
    }
}
