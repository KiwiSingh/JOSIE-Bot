import AVFoundation
import Foundation
import Speech

@Observable
class JosieVoiceManager: NSObject, AVSpeechSynthesizerDelegate {
  private let synthesizer = AVSpeechSynthesizer()
  private let audioEngine = AVAudioEngine()
  private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
  private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
  private var recognitionTask: SFSpeechRecognitionTask?

  var isListening = false
  var isMuted = true
  var selectedVoiceID = "com.apple.ttsbundle.siri_female_en-US_compact"

  override init() {
    super.init()
    synthesizer.delegate = self
  }

  func speak(_ text: String) {
    guard !isMuted else { return }
    // Filter out RP actions (text between asterisks) from audio
    let cleanText = text.replacingOccurrences(
      of: "\\*.*?\\*", with: "", options: .regularExpression)
    let utterance = AVSpeechUtterance(string: cleanText)
    utterance.voice =
      AVSpeechSynthesisVoice(identifier: selectedVoiceID)
      ?? AVSpeechSynthesisVoice(language: "en-US")
    utterance.rate = 0.52
    utterance.pitchMultiplier = 1.15

    synthesizer.stopSpeaking(at: .immediate)
    synthesizer.speak(utterance)
  }

  func toggleListening(onResult: @escaping (String) -> Void) {
    if isListening { stopListening() } else { startListening(onResult: onResult) }
  }

  private func startListening(onResult: @escaping (String) -> Void) {
    isListening = true
    recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
    let inputNode = audioEngine.inputNode
    let recordingFormat = inputNode.outputFormat(forBus: 0)

    inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
      self.recognitionRequest?.append(buffer)
    }

    try? audioEngine.start()
    recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest!) { result, _ in
      if let result = result { onResult(result.bestTranscription.formattedString) }
    }
  }

  private func stopListening() {
    audioEngine.stop()
    audioEngine.inputNode.removeTap(onBus: 0)
    recognitionRequest?.endAudio()
    recognitionTask?.cancel()
    isListening = false
  }
}
