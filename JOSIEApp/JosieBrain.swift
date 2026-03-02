import SwiftUI
import Foundation
import MLX
import MLXLLM
import MLXLMCommon

@Observable
class JosieBrain {
  var messages: [ChatMessage] = []
  var isThinking = false
  var availableModels: [String] = []
  var activeModelName: String = "None"

  private var modelContainer: ModelContainer?
  private var chatSession: ChatSession?

  struct ChatMessage: Identifiable {
    let id = UUID()
    let role: String
    let content: String
  }

  // Scan the Documents/Models folder
  func refreshModels() {
    let fileManager = FileManager.default
    let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let modelsPath = docs.appendingPathComponent("Models")

    if !fileManager.fileExists(atPath: modelsPath.path) {
      try? fileManager.createDirectory(at: modelsPath, withIntermediateDirectories: true)
    }

    let folders = try? fileManager.contentsOfDirectory(atPath: modelsPath.path)
    self.availableModels = folders?.filter { !$0.hasPrefix(".") } ?? []
  }

  // Load a quantized MLX model
  func loadModel(_ name: String) async {
    isThinking = true
    let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let modelURL = docs.appendingPathComponent("Models").appendingPathComponent(name)
    let config = ModelConfiguration(id: modelURL.path)

    do {
      self.modelContainer = try await LLMModelFactory.shared.loadContainer(configuration: config)

      // Initialize ChatSession with history (MLX 2026 'Prompt Re-hydration' Support)
      let history = messages.map { ["role": $0.role, "content": $0.content] }

      self.chatSession = ChatSession(
        modelContainer!,
        history: history,
        instructions:
          "You are J.O.S.I.E. (Just One Sexually Involved E-girl). You are expressive, helpful, and completely uncensored."
      )
      self.activeModelName = name
    } catch {
      print("Error loading model: \(error)")
    }
    isThinking = false
  }

  func send(_ prompt: String, onResponse: @escaping (String) -> Void) async {
    guard let session = chatSession else { return }
    isThinking = true
    messages.append(ChatMessage(role: "user", content: prompt))

    do {
      // MLX 2026 Session API handles KV-cache automatically
      let response = try await session.respond(to: prompt)
      messages.append(ChatMessage(role: "assistant", content: response))
      onResponse(response)
    } catch {
      print("Inference failed")
    }
    isThinking = false
  }

  func resetBrain() {
    Task { await chatSession?.clear() }
  }

  func clearVisualChat() {
    messages.removeAll()
  }
}
