import Foundation
import AVFoundation
import Combine

@MainActor
public class JosieVoiceManager: NSObject, ObservableObject {
    
    @Published public var isListening = false
    @Published public var isMuted = false

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

    // MARK: - Speech Toggle Stub

    public func toggleListening(onResult: @escaping (String) -> Void) {
        isListening.toggle()

        if isListening {
            print("🎙️ JOSIE is listening...")
        } else {
            print("🛑 Mic off")
        }
    }

    public func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}