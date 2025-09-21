import Foundation
import AVFoundation
import SwiftUI

enum SpeechFace: String, Codable { case front, back }

protocol SpeechEngineDelegate: AnyObject {
    func speechEngine(_ engine: SpeechEngine, didCompleteCardAt index: Int)
    func speechEngineDidCompleteAllCards(_ engine: SpeechEngine)
}

struct SpeechItem: Identifiable {
    let id = UUID()
    let text: String
    let langCode: String
    let rate: Float
    let preDelay: TimeInterval
    let postDelay: TimeInterval
    let cardIndex: Int?
    let face: SpeechFace?
    let isCardEnd: Bool // 標記是否為卡片的最後一個項目
}

final class SpeechEngine: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isPlaying: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var currentIndex: Int = 0
    @Published private(set) var currentCardIndex: Int? = nil
    @Published private(set) var currentFace: SpeechFace? = nil
    @Published private(set) var totalItems: Int = 0
    @Published private(set) var level: Double = 0 // 0...1, real-time RMS approx

    weak var delegate: SpeechEngineDelegate?

    private var queue: [SpeechItem] = []
    private let synth = AVSpeechSynthesizer()
    private let meterSynth = AVSpeechSynthesizer()
    private var pendingWork: DispatchWorkItem?

    override init() {
        super.init()
        synth.delegate = self
    }

    func play(queue: [SpeechItem]) {
        stop()
        self.queue = queue
        self.currentIndex = 0
        self.totalItems = queue.count
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
        totalItems = 0
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
        // publish card/face immediately for UI sync
        if let ci = item.cardIndex { currentCardIndex = ci }
        currentFace = item.face
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

            // Parallel metering: synthesize to buffers to compute RMS (no playback)
            let meterUtt = AVSpeechUtterance(string: item.text)
            meterUtt.voice = AVSpeechSynthesisVoice(language: item.langCode)
            meterUtt.rate = item.rate
            self.meterSynth.write(meterUtt) { [weak self] abuf in
                guard let self else { return }
                guard let pcm = abuf as? AVAudioPCMBuffer,
                      let ch = pcm.floatChannelData else { return }
                let frames = Int(pcm.frameLength)
                let chans = Int(pcm.format.channelCount)
                if frames == 0 || chans == 0 { return }
                var acc: Double = 0
                for c in 0..<chans {
                    let ptr = ch[c]
                    var sum: Double = 0
                    for i in 0..<frames { sum += Double(abs(ptr[i])) }
                    acc += sum / Double(frames)
                }
                let avg = acc / Double(chans)
                // Smooth to 0..1
                let newLevel = max(0, min(1, avg))
                DispatchQueue.main.async { self.level = self.level * 0.85 + newLevel * 0.15 }
            }
        }
    }

    private func advance() {
        // 檢查當前項目是否為卡片結束
        if currentIndex < queue.count {
            let currentItem = queue[currentIndex]
            if currentItem.isCardEnd, let cardIndex = currentItem.cardIndex {
                delegate?.speechEngine(self, didCompleteCardAt: cardIndex)
            }
        }

        currentIndex += 1
        level = 0

        if currentIndex < queue.count {
            playCurrent()
        } else {
            delegate?.speechEngineDidCompleteAllCards(self)
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
            NotificationCenter.default.post(name: .ttsError, object: nil, userInfo: [AppEventKeys.error: (error as NSError).localizedDescription])
        }
        #endif
    }
}
