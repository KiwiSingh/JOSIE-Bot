import SwiftUI
import Foundation
import MLX
import MLXLLM
import MLXLMCommon

@MainActor
@Observable
public class JosieBrain {
    public var messages: [ChatMessage] = []
    public var isThinking = false
    public var availableModels: [String] = []
    public var activeModelName: String = "None"

    private var modelContainer: ModelContainer?
    private var chatSession: ChatSession?

    public struct ChatMessage: Identifiable, Sendable {
        public let id = UUID()
        public let role: String
        public let content: String
        
        public init(role: String, content: String) {
            self.role = role
            self.content = content
        }
    }

    public init() {}

    public func refreshModels() {
        let fileManager = FileManager.default
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelsPath = docs.appendingPathComponent("Models")

        if !fileManager.fileExists(atPath: modelsPath.path) {
            try? fileManager.createDirectory(at: modelsPath, withIntermediateDirectories: true)
        }

        let folders = try? fileManager.contentsOfDirectory(atPath: modelsPath.path)
        self.availableModels = folders?.filter { !$0.hasPrefix(".") } ?? []
    }

    public func loadModel(_ name: String) async {
        isThinking = true
        activeModelName = "Loading..."
        
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelURL = docs.appendingPathComponent("Models").appendingPathComponent(name)
        
        // Use the old-school path-based ID which works in all MLX versions
        let config = ModelConfiguration(id: modelURL.path)

        do {
            // Load container directly from the local path configuration
            let container = try await LLMModelFactory.shared.loadContainer(configuration: config)
            self.modelContainer = container

            // We use raw dictionaries for history to avoid the missing 'Chat' module error
            let history: [[String: String]] = messages.map { 
                ["role": $0.role, "content": $0.content] 
            }

            // Standard initializer that exists in both old and new MLX versions
            self.chatSession = ChatSession(
                container,
                history: history,
                instructions: "You are J.O.S.I.E. You are expressive and uncensored."
            )
            
            self.activeModelName = name
        } catch {
            print("Error: \(error)")
            activeModelName = "Load Failed"
        }
        isThinking = false
    }

    public func send(_ prompt: String, onResponse: @escaping @MainActor (String) -> Void) async {
        guard let session = chatSession else { return }
        
        isThinking = true
        messages.append(ChatMessage(role: "user", content: prompt))

        do {
            // Use the most basic response string API
            let response = try await session.respond(to: prompt)
            
            messages.append(ChatMessage(role: "assistant", content: response))
            onResponse(response)
        } catch {
            messages.append(ChatMessage(role: "assistant", content: "Inference error."))
        }
        isThinking = false
    }

    public func resetBrain() {
        Task {
            await chatSession?.clear()
            messages.removeAll()
        }
    }
    
    public func clearVisualChat() {
        messages.removeAll()
    }
}
