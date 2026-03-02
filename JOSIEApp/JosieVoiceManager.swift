import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
public class JosieVoiceManager: NSObject, Sendable {
    public var isListening = false
    public var isMuted = false
    
    // 2026 FIX: Isolated to MainActor to handle non-Sendable AVSpeechSynthesizer
    @MainActor private let synthesizer = AVSpeechSynthesizer()
    
    public override init() {
        super.init()
    }

    /// Triggers J.O.S.I.E. to speak the provided text
    public func speak(_ text: String) {
        guard !isMuted else { return }
        
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.52 // Natural e-girl cadence
        utterance.pitchMultiplier = 1.2 // Slightly higher pitch for J.O.S.I.E.
        
        // Ensure the call stays on the MainActor for the non-Sendable synthesizer
        Task { @MainActor in
            if synthesizer.isSpeaking {
                synthesizer.stopSpeaking(at: .immediate)
            }
            synthesizer.speak(utterance)
        }
    }
    
    /// Stub for Speech-to-Text toggle
    public func toggleListening(onResult: @escaping (String) -> Void) {
        // Recognition logic would be integrated here
        isListening.toggle()
        
        if isListening {
            print("🎙️ JOSIE is listening...")
        } else {
            print("🛑 Mic off")
        }
    }

    /// Force stops any current speech
    public func stopSpeaking() {
        Task { @MainActor in
            synthesizer.stopSpeaking(at: .immediate)
        }
    }
}

