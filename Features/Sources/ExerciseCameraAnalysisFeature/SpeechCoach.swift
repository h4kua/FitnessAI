#if canImport(AVFoundation)
import AVFoundation
import Foundation

/// Thin, thread-safe wrapper around ``AVSpeechSynthesizer`` for on-device TTS.
///
/// Designed to be owned by a `@MainActor` ViewModel — all methods are safe to
/// call from the main thread.  Marked `@unchecked Sendable` because
/// `AVSpeechSynthesizer` is internally thread-safe even though Swift doesn't
/// yet expose that in its type system.
///
/// Usage:
/// ```swift
/// coach.speak("Lower your hips more")
/// coach.stop()
/// ```
public final class SpeechCoach: @unchecked Sendable {

    // MARK: - Private

    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Init

    public init() {
        // Allow speech to play over background music and duck it slightly
        // so the user can still hear their workout playlist.
        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default,
            options: [.mixWithOthers, .duckOthers]
        )
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // MARK: - Public API

    /// Speak `text` aloud, interrupting any speech already in progress.
    ///
    /// - Parameters:
    ///   - text:     The string to synthesise.
    ///   - language: BCP-47 language tag (default `"en-US"`).
    ///   - rate:     Speech rate 0.0 – 1.0 (AVSpeechUtteranceDefaultSpeechRate ≈ 0.5).
    public func speak(_ text: String, language: String = "en-US", rate: Float = 0.50) {
        // Stop current speech at the next word boundary so transitions sound natural.
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .word)
        }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice            = AVSpeechSynthesisVoice(language: language)
        utterance.rate             = rate
        utterance.volume           = 1.0
        utterance.pitchMultiplier  = 1.05
        utterance.preUtteranceDelay  = 0.05
        utterance.postUtteranceDelay = 0.05

        synthesizer.speak(utterance)
    }

    /// Stop any ongoing speech immediately.
    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    /// `true` while the synthesizer is producing audio.
    public var isSpeaking: Bool { synthesizer.isSpeaking }
}
#endif
