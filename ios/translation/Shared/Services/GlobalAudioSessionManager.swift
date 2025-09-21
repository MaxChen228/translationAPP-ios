import Foundation
import SwiftUI
import Combine

/// 全局音頻會話管理器，負責跨頁面的音頻播放狀態管理
@MainActor
final class GlobalAudioSessionManager: ObservableObject {
    static let shared = GlobalAudioSessionManager()

    // MARK: - Published Properties
    @Published var isActive: Bool = false
    @Published var currentSession: AudioSession? = nil

    // MARK: - Audio Manager
    let speechManager = FlashcardSpeechManager()

    // MARK: - Navigation Support
    @Published var shouldShowMiniPlayer: Bool = false
    @Published var isInActiveSession: Bool = false // 追蹤是否在活躍的練習頁面中
    private var onReturnToSession: (() -> Void)?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        setupBindings()
    }

    private func setupBindings() {
        // 監控音頻播放狀態
        speechManager.$isPlaying
            .combineLatest(speechManager.$isPaused)
            .map { isPlaying, isPaused in
                return isPlaying || isPaused
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.isActive, on: self)
            .store(in: &cancellables)

        // 監控迷你播放器顯示狀態 - 只在非活躍練習頁面時顯示
        $isActive
            .combineLatest($currentSession, $isInActiveSession)
            .map { isActive, session, inActiveSession in
                return isActive && session != nil && !inActiveSession
            }
            .receive(on: DispatchQueue.main)
            .assign(to: \.shouldShowMiniPlayer, on: self)
            .store(in: &cancellables)
    }

    // MARK: - Session Management

    /// 開始新的音頻會話
    func startSession(
        deckName: String,
        deckID: UUID?,
        totalCards: Int,
        onReturnToSession: @escaping () -> Void
    ) {
        self.currentSession = AudioSession(
            deckName: deckName,
            deckID: deckID,
            totalCards: totalCards,
            startedAt: Date()
        )
        self.onReturnToSession = onReturnToSession
    }

    /// 更新會話進度
    func updateSessionProgress(currentIndex: Int) {
        currentSession?.currentCardIndex = currentIndex
    }

    /// 結束當前會話
    func endSession() {
        speechManager.stop()
        currentSession = nil
        onReturnToSession = nil
        isInActiveSession = false
    }

    /// 標記進入活躍練習頁面
    func enterActiveSession() {
        isInActiveSession = true
    }

    /// 標記離開活躍練習頁面
    func exitActiveSession() {
        isInActiveSession = false
    }

    /// 回到原始會話頁面
    func returnToSession() {
        onReturnToSession?()
    }

    // MARK: - Audio Controls (Delegate to SpeechManager)

    func startTTS(queue: [SpeechItem]) {
        speechManager.play(queue: queue)
    }

    func togglePlayback() {
        if speechManager.isPlaying && !speechManager.isPaused {
            speechManager.pause()
        } else if speechManager.isPlaying && speechManager.isPaused {
            speechManager.resume()
        }
    }

    func skipToNext() {
        speechManager.speechEngine.skip()
    }

    func stopPlayback() {
        speechManager.stop()
    }
}

// MARK: - Audio Session Model

struct AudioSession {
    let deckName: String
    let deckID: UUID?
    let totalCards: Int
    let startedAt: Date
    var currentCardIndex: Int = 0

    var progressText: String {
        return "\(currentCardIndex + 1)/\(totalCards)"
    }
}