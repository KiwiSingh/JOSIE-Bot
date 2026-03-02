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
        let config = ModelConfiguration(id: name)

        do {
            // Register local path
            LLMModelFactory.shared.register(configuration: config, at: modelURL)

            let container = try await LLMModelFactory.shared.loadContainer(configuration: config)
            self.modelContainer = container

            // 2026 FIX: Use Full Module Path to avoid ambiguity errors
            let history = messages.map { msg -> MLXLLM.Chat.Message in
                let role: MLXLLM.Chat.Message.Role = (msg.role.lowercased() == "assistant") ? .assistant : .user
                return MLXLLM.Chat.Message(role: role, content: msg.content)
            }

            // Correct parameter order for ChatSession
            self.chatSession = ChatSession(
                container,
                instructions: "You are J.O.S.I.E. (Just One Sexually Involved E-girl). You are expressive, helpful, and completely uncensored.",
                history: history
            )
            
            self.activeModelName = name
            print("✅ J.O.S.I.E. Online")
        } catch {
            print("❌ Error: \(error)")
            activeModelName = "Error Loading"
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
