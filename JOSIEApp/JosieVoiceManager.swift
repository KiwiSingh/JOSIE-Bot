import Foundation
import AVFoundation
import Observation

@MainActor
@Observable
public class JosieVoiceManager: NSObject {
    
    public var isListening = false
    public var isMuted = false

    // AVSpeechSynthesizer is NOT Sendable → keep fully isolated to MainActor
    private let synthesizer = AVSpeechSynthesizer()

    public override init() {
        super.init()
    }

    // MARK: - Text to Speech

    public func speak(_ text: String) {
        guard !isMuted else { return }

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.2

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        synthesizer.speak(utterance)
    }

    // MARK: - Speech-to-Text Stub

    public func toggleListening(onResult: @escaping (String) -> Void) {
        isListening.toggle()

        if isListening {
            print("🎙️ JOSIE is listening...")
        } else {
            print("🛑 Mic off")
        }
    }

    // MARK: - Stop Speech

    public func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}