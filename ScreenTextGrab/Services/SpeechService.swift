import AVFoundation
import Foundation

@MainActor
protocol SpeechManaging: AnyObject {
    var speechState: SpeechPlaybackState { get }
    func toggleSpeechPlayback(for text: String)
    func stopSpeechPlayback()
}

@MainActor
final class SpeechService: NSObject {
    private let synthesizer: AVSpeechSynthesizer
    private let onStateChange: (SpeechPlaybackState) -> Void

    private(set) var state: SpeechPlaybackState = .idle {
        didSet {
            guard oldValue != state else { return }
            onStateChange(state)
        }
    }

    private var activeTextSignature: String?

    init(
        synthesizer: AVSpeechSynthesizer = AVSpeechSynthesizer(),
        onStateChange: @escaping (SpeechPlaybackState) -> Void = { _ in }
    ) {
        self.synthesizer = synthesizer
        self.onStateChange = onStateChange
        super.init()
        self.synthesizer.delegate = self
    }

    func toggleSpeaking(_ text: String) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard SmartActionBuilder.shouldOfferReadAloud(for: normalized) else {
            stopSpeaking()
            return
        }

        if state == .speaking, activeTextSignature == normalized {
            stopSpeaking()
            return
        }

        speak(normalized)
    }

    func stopSpeaking() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        activeTextSignature = nil
        state = .idle
    }

    private func speak(_ text: String) {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        let utterance = AVSpeechUtterance(string: preparedUtteranceText(from: text))
        utterance.voice = preferredVoice(for: text)
        utterance.rate = 0.5
        utterance.volume = 1

        activeTextSignature = text
        state = .speaking
        synthesizer.speak(utterance)
    }

    private func preferredVoice(for text: String) -> AVSpeechSynthesisVoice? {
        let preferredLanguage = SmartActionBuilder.preferredSpeechLanguage(for: text)
        if let exactVoice = AVSpeechSynthesisVoice(language: preferredLanguage) {
            return exactVoice
        }

        let languagePrefix = String(preferredLanguage.prefix(2))
        return AVSpeechSynthesisVoice.speechVoices().first { voice in
            voice.language.hasPrefix(languagePrefix)
        }
    }

    private func preparedUtteranceText(from text: String) -> String {
        let cleanedLines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !cleanedLines.isEmpty else {
            return text
        }

        return cleanedLines.joined(separator: ". ")
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.activeTextSignature = nil
            self?.state = .idle
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in
            self?.activeTextSignature = nil
            self?.state = .idle
        }
    }
}
