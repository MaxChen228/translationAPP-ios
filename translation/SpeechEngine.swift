import Foundation
import AVFoundation
import SwiftUI

struct SpeechItem: Identifiable {
    let id = UUID()
    let text: String
    let langCode: String
    let rate: Float
    let preDelay: TimeInterval
    let postDelay: TimeInterval
}

final class SpeechEngine: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var currentIndex: Int = 0

    private var queue: [SpeechItem] = []
    private let synth = AVSpeechSynthesizer()
    private var pendingWork: DispatchWorkItem?

    override init() {
        super.init()
        synth.delegate = self
    }

    func play(queue: [SpeechItem]) {
        stop()
        self.queue = queue
        self.currentIndex = 0
        configureAudioSession()
        isPlaying = true
        isPaused = false
        playCurrent()
    }

    func pause() {
        guard isPlaying, !isPaused else { return }
        pendingWork?.cancel()
        synth.pauseSpeaking(at: .immediate)
        isPaused = true
    }

    func resume() {
        guard isPlaying, isPaused else { return }
        if !synth.continueSpeaking() {
            playCurrent()
        }
        isPaused = false
    }

    func stop() {
        pendingWork?.cancel()
        synth.stopSpeaking(at: .immediate)
        queue = []
        currentIndex = 0
        isPlaying = false
        isPaused = false
    }

    func skip() {
        pendingWork?.cancel()
        synth.stopSpeaking(at: .immediate)
        advance()
    }

    // MARK: - AVSpeechSynthesizerDelegate
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        guard isPlaying else { return }
        let item = queue[currentIndex]
        schedule(delay: item.postDelay) { [weak self] in
            self?.advance()
        }
    }

    // MARK: - Internal
    private func playCurrent() {
        guard isPlaying else { return }
        guard currentIndex < queue.count else { stop(); return }
        let item = queue[currentIndex]
        schedule(delay: item.preDelay) { [weak self] in
            guard let self else { return }
            if item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Silent gap only
                self.schedule(delay: item.postDelay) {
                    self.advance()
                }
                return
            }
            let utt = AVSpeechUtterance(string: item.text)
            utt.voice = AVSpeechSynthesisVoice(language: item.langCode)
            utt.rate = item.rate
            self.synth.speak(utt)
        }
    }

    private func advance() {
        currentIndex += 1
        if currentIndex < queue.count {
            playCurrent()
        } else {
            stop()
        }
    }

    private func schedule(delay: TimeInterval, _ block: @escaping () -> Void) {
        if delay <= 0 { block(); return }
        let work = DispatchWorkItem(block: block)
        pendingWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func configureAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // ignore
        }
        #endif
    }
}

