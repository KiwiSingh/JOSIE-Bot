import Foundation
import AVFoundation
import Speech

@MainActor
public final class JosieVoiceManager: NSObject, ObservableObject {
    
    public enum VoiceLocale: String, CaseIterable, Identifiable {
        case americanEnglish = "en-US"
        case britishEnglish = "en-GB"
        case indianEnglish = "en-IN"

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .americanEnglish:
                return "American English"
            case .britishEnglish:
                return "British English"
            case .indianEnglish:
                return "Indian English"
            }
        }
    }
    
    @Published public var isListening = false
    @Published public var isMuted = false
    @Published public var lastTranscript = ""
    @Published public var voiceLocale: VoiceLocale = .americanEnglish
    @Published public var voiceEnabled: Bool = true
    
    private let synthesizer = AVSpeechSynthesizer()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    public override init() {
        super.init()
        speechRecognizer?.delegate = self
    }
    
    // MARK: - Text to Speech
    
    public func speak(_ text: String) {
        guard voiceEnabled, !isMuted else { return }

        configureAudioSessionForPlayback()

        let cleanedText = stripEmojis(from: text)
        let utterance = AVSpeechUtterance(string: cleanedText)
        let voice = preferredFemaleVoice(for: voiceLocale.rawValue)
        utterance.voice = voice
        utterance.rate = 0.52
        utterance.pitchMultiplier = 1.2
        
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        
        synthesizer.speak(utterance)
    }
    
    public func stopSpeaking() {
        synthesizer.stopSpeaking(at: .immediate)
    }
    
    // MARK: - Speech to Text
    
    public func toggleListening(onResult: @escaping (String) -> Void) {
        guard voiceEnabled else { return }

        if isListening {
            stopListening()
        } else {
            Task { @MainActor in
                let authorized = await requestPermissions()
                guard authorized else {
                    print("❌ Speech permissions denied")
                    return
                }
                do {
                    try startListening(onResult: onResult)
                } catch {
                    print("❌ Failed to start listening:", error)
                }
            }
        }
    }
    
    private func requestPermissions() async -> Bool {
        let speechAuthorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        let micAuthorized = await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                    continuation.resume(returning: allowed)
                }
            }
        }
        return speechAuthorized && micAuthorized
    }
    
    private func startListening(onResult: @escaping (String) -> Void) throws {
        if audioEngine.isRunning {
            stopListening()
        }
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .voiceChat,
            options: [.defaultToSpeaker, .allowBluetoothHFP, .duckOthers]
        )
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            request.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        isListening = true
        
        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in
                    self.lastTranscript = text
                    if result.isFinal {
                        onResult(text)
                        self.stopListening()
                    }
                }
            }
            if error != nil {
                Task { @MainActor in
                    self.stopListening()
                }
            }
        }
    }
    
    private func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isListening = false
    }

    private func preferredFemaleVoice(for locale: String) -> AVSpeechSynthesisVoice? {
        let voices = AVSpeechSynthesisVoice.speechVoices().filter { $0.language == locale }
        if let female = voices.first(where: { $0.gender == .female }) {
            return female
        }

        return AVSpeechSynthesisVoice(language: locale)
    }

    private func stripEmojis(from text: String) -> String {
        let scalars = text.unicodeScalars.filter { scalar in
            if scalar.properties.isEmojiPresentation {
                return false
            }
            if scalar.properties.isEmoji {
                return false
            }
            return true
        }
        return String(String.UnicodeScalarView(scalars))
    }

    private func configureAudioSessionForPlayback() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(
                .playAndRecord,
                mode: .voiceChat,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Failed to configure audio session:", error)
        }
    }
}

extension JosieVoiceManager: SFSpeechRecognizerDelegate {
}
