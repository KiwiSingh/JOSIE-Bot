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
    public var memoryUsage: String = "0 MB"

    // FIX: Marked as nonisolated to prevent Swift 6 Actor-isolation errors
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

    public init() {
        startMemoryMonitor()
    }

    private func startMemoryMonitor() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateMemoryUsage()
            }
        }
    }

    private func updateMemoryUsage() {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size)
        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let usedMB = taskInfo.resident_size / 1024 / 1024
            self.memoryUsage = "\(usedMB) MB"
        }
    }

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
        let config = ModelConfiguration(id: modelURL.path)

        do {
            LLMModelFactory.shared.register(configuration: config, at: modelURL)
            let container = try await LLMModelFactory.shared.loadContainer(configuration: config)
            self.modelContainer = container

            // FIX: Explicitly use the MLXLLM namespacing
            var history = [MLXLLM.Chat.Message]()
            for msg in messages {
                let role: MLXLLM.Chat.Message.Role = (msg.role.lowercased() == "assistant") ? .assistant : .user
                history.append(MLXLLM.Chat.Message(role: role, content: msg.content))
            }

            self.chatSession = ChatSession(container, instructions: "You are J.O.S.I.E.", history: history)
            self.activeModelName = name
        } catch {
            activeModelName = "Load Error"
        }
        isThinking = false
    }

    public func send(_ prompt: String, onResponse: @escaping @MainActor (String) -> Void) async {
        guard let session = chatSession else { return }
        isThinking = true
        messages.append(ChatMessage(role: "user", content: prompt))

        // FIX: Wrap in a simple Task rather than Detached to inherit Actor context
        do {
            let response = try await session.respond(to: prompt)
            messages.append(ChatMessage(role: "assistant", content: response))
            onResponse(response)
        } catch {
            messages.append(ChatMessage(role: "assistant", content: "Error: \(error.localizedDescription)"))
        }
        isThinking = false
    }

    public func resetBrain() {
        Task {
            await chatSession?.clear()
            messages.removeAll()
            isThinking = false
        }
    }
    
    public func clearVisualChat() {
        messages.removeAll()
    }
}
