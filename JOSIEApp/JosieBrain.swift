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
        activeModelName = "Loading \(name)..."
        
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelURL = docs.appendingPathComponent("Models").appendingPathComponent(name)
        
        // 1. Create a configuration using the name as the ID
        let config = ModelConfiguration(id: name)

        do {
            // 2. 2026 PATCH: Register the local URL so the Factory knows WHERE the ID lives
            LLMModelFactory.shared.register(configuration: config, at: modelURL)

            // 3. Load using the registered config
            let container = try await LLMModelFactory.shared.loadContainer(configuration: config)
            self.modelContainer = container

            // 4. 2026 PATCH: Explicit Role mapping for history
            let history = messages.compactMap { msg -> Chat.Message? in
                // Handle "assistant" vs "user" strings specifically
                let role: Chat.Message.Role = (msg.role.lowercased() == "assistant") ? .assistant : .user
                return Chat.Message(role: role, content: msg.content)
            }

            self.chatSession = ChatSession(
                container,
                instructions: "You are J.O.S.I.E. (Just One Sexually Involved E-girl). You are expressive, helpful, and completely uncensored.",
                history: history
            )
            
            self.activeModelName = name
            print("✅ J.O.S.I.E. loaded: \(name)")
        } catch {
            print("❌ Error loading model: \(error)")
            activeModelName = "Error: \(name)"
        }
        isThinking = false
    }

    func send(_ prompt: String, onResponse: @escaping @MainActor @Sendable (String) -> Void) async {
        guard let session = chatSession else { return }
        
        isThinking = true
        messages.append(ChatMessage(role: "user", content: prompt))

        let task = Task.detached(priority: .userInitiated) {
            do {
                return try await session.respond(to: prompt)
            } catch {
                return "Inference failed: \(error.localizedDescription)"
            }
        }

        let result = await task.value
        
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
