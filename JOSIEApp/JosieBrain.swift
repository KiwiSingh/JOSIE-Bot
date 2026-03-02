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

    // Marked as nonisolated to prevent actor-locking during heavy inference
    private var modelContainer: ModelContainer?
    private var chatSession: ChatSession?

    struct ChatMessage: Identifiable, Sendable {
        let id: UUID = UUID()
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
            // Updated for MLX 2026 container loading
            let container = try await LLMModelFactory.shared.loadContainer(configuration: config)
            self.modelContainer = container

            // Mapping to the required Chat.Message type
            let history = messages.map { Chat.Message(role: $0.role, content: $0.content) }

            // Initialize session
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

    func send(_ prompt: String, onResponse: @escaping @MainActor @Sendable (String) -> Void) async {
        guard let session = chatSession else { return }
        
        isThinking = true
        messages.append(ChatMessage(role: "user", content: prompt))

        // We wrap the inference in a non-isolated Task to keep the UI responsive
        // while satisfying the Swift 6 strict concurrency checks
        let task = Task.detached(priority: .userInitiated) {
            do {
                let response = try await session.respond(to: prompt)
                return response
            } catch {
                return "Inference failed: \(error.localizedDescription)"
            }
        }

        let result = await task.value
        
        // Back on the MainActor (thanks to the class decoration)
        messages.append(ChatMessage(role: "assistant", content: result))
        onResponse(result)
        isThinking = false
    }

    func resetBrain() {
        Task {
            await chatSession?.clear()
            messages.removeAll()
            isThinking = false
        }
    }
    
    func clearVisualChat() {
        messages.removeAll()
    }
}
