import Foundation
import AVFoundation
import SwiftUI

/// A lightweight, one-shot speaker for instant playback that does not
/// interfere with the continuous SpeechEngine UI state.
///
/// Behavior:
/// - New requests cancel the previous instant utterance (no queueing).
/// - If a SpeechEngine is currently playing, it pauses, plays the instant
///   utterance, then (option B) resumes after a small buffer window unless
///   another instant request happens during the window.
@MainActor
final class InstantSpeaker: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published private(set) var isSpeaking: Bool = false

    private let synth = AVSpeechSynthesizer()
    private var pendingResume: DispatchWorkItem?
    private var pausedByInstant: Bool = false
    private var bufferWindow: TimeInterval

    override init() {
        // Default buffer window 0.7s (per decision: B)
        self.bufferWindow = 0.7
        super.init()
        synth.delegate = self
    }

    func setBufferWindow(_ seconds: TimeInterval) { bufferWindow = max(0, seconds) }

    /// Speak a single utterance immediately.
    /// - Parameters:
    ///   - text: Content to speak (already composed if needed).
    ///   - lang: BCP-47 language code, strictly use provided code (decision: A).
    ///   - rate: AVSpeechUtterance rate (0.0~1.0 typical range 0.3~0.6 here).
    ///   - speech: Optional continuous SpeechEngine to collaborate with
    ///             (pause/resume around instant playback).
    func speak(text: String, lang: String, rate: Float, speech: SpeechEngine?) {
        // Cancel any scheduled resume from prior instant
        pendingResume?.cancel(); pendingResume = nil

        // If continuous is actively playing, pause it and mark ownership
        if let speech, speech.isPlaying && !speech.isPaused {
            speech.pause()
            pausedByInstant = true
        }

        // Stop any current instant speaking and start fresh
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        configureAudioSession()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            scheduleResumeIfNeeded(speech)
            return
        }

        let utt = AVSpeechUtterance(string: trimmed)
        utt.voice = pickVoice(for: lang)
        utt.rate = rate
        isSpeaking = true
        synth.speak(utt)

        // Note: resume is scheduled in delegate didFinish.
    }

    func cancel(speech: SpeechEngine?) {
        pendingResume?.cancel(); pendingResume = nil
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }
        isSpeaking = false
        scheduleResumeIfNeeded(speech)
    }

    // MARK: - AVSpeechSynthesizerDelegate
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.isSpeaking = false
            // Schedule buffered resume (decision B)
            self.scheduleResumeIfNeeded(nil)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.isSpeaking = false
        }
    }

    // MARK: - Helpers
    private func scheduleResumeIfNeeded(_ speechOpt: SpeechEngine?) {
        guard pausedByInstant else { return }
        let speechRef = speechOpt
        // Buffer window: if another instant speak fires within window,
        // this work will be canceled by the next call to speak().
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if let s = speechRef, s.isPlaying { s.resume() }
            self.pausedByInstant = false
        }
        pendingResume = work
        DispatchQueue.main.asyncAfter(deadline: .now() + bufferWindow, execute: work)
    }

    private func pickVoice(for lang: String) -> AVSpeechSynthesisVoice? {
        // Strictly follow provided language code; fallback to same language prefix if exact match missing.
        if let v = AVSpeechSynthesisVoice(language: lang) { return v }
        let prefix = lang.split(separator: "-").first.map(String.init) ?? lang
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(prefix) }
        return candidates.first ?? AVSpeechSynthesisVoice(language: lang)
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
