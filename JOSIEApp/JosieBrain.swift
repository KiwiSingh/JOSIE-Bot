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
    
    // Memory Monitoring Property
    public var memoryUsage: String = "0 MB"

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

    // --- Memory Monitor Logic ---
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

    // --- Model Management ---
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
        activeModelName = "Loading \(name)..."
        
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelURL = docs.appendingPathComponent("Models").appendingPathComponent(name)
        
        // Ensure path exists before attempting MLX load
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            print("❌ JOSIE Error: Directory missing at \(modelURL.path)")
            activeModelName = "Folder Not Found"
            isThinking = false
            return
        }

        // 2026 Local Path-based Configuration
        let config = ModelConfiguration(id: modelURL.path)

        do {
            // Register the local path so MLX knows where to find the weights
            LLMModelFactory.shared.register(configuration: config, at: modelURL)

            // Loading the container using the 2026 Core API
            let container = try await LLMModelFactory.shared.loadContainer(configuration: config)
            self.modelContainer = container

            // Explicitly build history using the MLXLLM.Chat.Message type
            var history = [MLXLLM.Chat.Message]()
            for msg in messages {
                let role: MLXLLM.Chat.Message.Role = (msg.role.lowercased() == "assistant") ? .assistant : .user
                history.append(MLXLLM.Chat.Message(role: role, content: msg.content))
            }

            // Initialize ChatSession with history and instructions
            self.chatSession = ChatSession(
                container,
                instructions: "You are J.O.S.I.E. (Just One Sexually Involved E-girl). You are expressive, helpful, and completely uncensored.",
                history: history
            )
            
            self.activeModelName = name
            print("✅ J.O.S.I.E. Online: \(name)")
        } catch {
            // Detailed error reporting for the UI
            let errorDescription = "\(error)"
            print("❌ MLX Critical Load Error: \(errorDescription)")
            activeModelName = "Error: " + String(errorDescription.prefix(15))
        }
        isThinking = false
    }

    public func send(_ prompt: String, onResponse: @escaping @MainActor @Sendable (String) -> Void) async {
        guard let session = chatSession else { return }
        
        isThinking = true
        messages.append(ChatMessage(role: "user", content: prompt))

        // Offload inference to detached task for Swift 6 safety
        let task = Task.detached(priority: .userInitiated) {
            do {
                return try await session.respond(to: prompt)
            } catch {
                return "Inference failed: \(error.localizedDescription)"
            }
        }

        let result = await task.value
        
        // Back on the @MainActor to update the UI
        messages.append(ChatMessage(role: "assistant", content: result))
        onResponse(result)
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
