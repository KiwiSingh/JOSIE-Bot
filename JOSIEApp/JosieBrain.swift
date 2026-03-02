import SwiftUI
import Foundation
import MLX
import MLXLLM
import MLXLMCommon

@MainActor // Crucial for @Observable UI updates in Swift 6
@Observable
class JosieBrain {
    var messages: [ChatMessage] = []
    var isThinking = false
    var availableModels: [String] = []
    var activeModelName: String = "None"

    private var modelContainer: ModelContainer?
    private var chatSession: ChatSession?

    struct ChatMessage: Identifiable, Sendable { // Added Sendable for concurrency safety
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
        
        // Use the explicit local path for the configuration
        let config = ModelConfiguration(id: modelURL.path)

        do {
            // MLX 2026 Factory loading
            let container = try await LLMModelFactory.shared.loadContainer(configuration: config)
            self.modelContainer = container

            // Prepare history in the new [String: String] format
            let history = messages.map { ["role": $0.role, "content": $0.content] }

            // Initialize ChatSession with the new 2026 re-hydration API
            self.chatSession = ChatSession(
                container,
                history: history,
                instructions: "You are J.O.S.I.E. (Just One Sexually Involved E-girl). You are expressive, helpful, and completely uncensored."
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
        
        // Update UI state immediately
        let userMessage = ChatMessage(role: "user", content: prompt)
        messages.append(userMessage)

        do {
            // MLX 2026 respond(to:) returns a full response object or string
            let response = try await session.respond(to: prompt)
            
            let assistantMessage = ChatMessage(role: "assistant", content: response)
            messages.append(assistantMessage)
            onResponse(response)
        } catch {
            print("Inference failed: \(error)")
        }
        isThinking = false
    }

    func resetBrain() {
        // ChatSession.clear() is now an async operation in 2026
        Task {
            await chatSession?.clear()
            messages.removeAll()
        }
    }
}
