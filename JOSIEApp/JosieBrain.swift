import SwiftUI
import Foundation
import MLX
import MLXLLM
import MLXLMCommon

@MainActor
@Observable
class JosieBrain {
    var messages: [ChatMessage] = []
    var isThinking = false
    var availableModels: [String] = []
    var activeModelName: String = "None"

    private var modelContainer: ModelContainer?
    private var chatSession: ChatSession?

    struct ChatMessage: Identifiable, Sendable {
        let id = UUID()
        let role: String
        let content: String
    }

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

    func loadModel(_ name: String) async {
        isThinking = true
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelURL = docs.appendingPathComponent("Models").appendingPathComponent(name)
        let config = ModelConfiguration(id: modelURL.path)

        do {
            let container = try await LLMModelFactory.shared.loadContainer(configuration: config)
            self.modelContainer = container

            // 2026 FIX: MLX now requires Chat.Message objects instead of Dictionaries
            let history = messages.map { Chat.Message(role: $0.role, content: $0.content) }

            // 2026 FIX: Updated ChatSession initializer signature
            self.chatSession = ChatSession(
                container,
                instructions: "You are J.O.S.I.E. (Just One Sexually Involved E-girl). You are expressive, helpful, and completely uncensored.",
                history: history
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
            // 2026 FIX: Use the updated respond API
            let response = try await session.respond(to: prompt)
            
            messages.append(ChatMessage(role: "assistant", content: response))
            onResponse(response)
        } catch {
            print("Inference failed: \(error)")
        }
        isThinking = false
    }

    func resetBrain() {
        Task {
            await chatSession?.clear()
            messages.removeAll()
        }
    }
    
    func clearVisualChat() {
        messages.removeAll()
    }
}
