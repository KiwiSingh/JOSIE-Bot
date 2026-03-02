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
        
        // Use the absolute path as the configuration ID
        let config = ModelConfiguration(id: modelURL.path)

        do {
            // Load container
            let container = try await LLMModelFactory.shared.loadContainer(configuration: config)
            self.modelContainer = container

            // FIX: Use an empty history array first to ensure the initializer matches,
            // then we'll handle the messages.
            self.chatSession = ChatSession(
                container,
                instructions: "You are J.O.S.I.E. You are expressive and uncensored."
            )
            
            self.activeModelName = name
            print("✅ J.O.S.I.E. Online")
        } catch {
            print("❌ Error: \(error)")
            activeModelName = "Load Failed"
        }
        isThinking = false
    }

    public func send(_ prompt: String, onResponse: @escaping @MainActor (String) -> Void) async {
        guard let session = chatSession else { return }
        
        isThinking = true
        let userMsg = ChatMessage(role: "user", content: prompt)
        messages.append(userMsg)

        do {
            // Standard respond call
            let response = try await session.respond(to: prompt)
            
            let assistantMsg = ChatMessage(role: "assistant", content: response)
            messages.append(assistantMsg)
            onResponse(response)
        } catch {
            print("Inference failed")
        }
        isThinking = false
    }

    public func resetBrain() {
        let session = chatSession
        Task {
            await session?.clear()
            messages.removeAll()
            isThinking = false
        }
    }
    
    public func clearVisualChat() {
        messages.removeAll()
    }
}
