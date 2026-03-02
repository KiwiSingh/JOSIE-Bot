import Foundation
import AVFoundation

@Observable
@MainActor
public class JosieVoiceManager: NSObject, Sendable {
    public var isListening = false
    public var isMuted = false
    
    // FIX: Marking the property as MainActor-isolated
    @MainActor private let synthesizer = AVSpeechSynthesizer()
    
    public override init() {
        super.init()
    }

    public func speak(_ text: String) {
        guard !isMuted else { return }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        
        Task { @MainActor in
            synthesizer.speak(utterance)
        }
    }
    
    public func toggleListening(onResult: @escaping (String) -> Void) {
        // Logic for speech recognition would go here
        isListening.toggle()
    }
}

