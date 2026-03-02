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

    private var modelContainer: ModelContainer?
    private var chatSession: ChatSession?

    public struct ChatMessage: Identifiable, Sendable {
        public let id = UUID()
        public let role: String
        public let content: String
        public init(role: String, content: String) { self.role = role; self.content = content }
    }

    public init() { startMemoryMonitor() }

    private func startMemoryMonitor() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in self.updateMemoryUsage() }
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
            self.memoryUsage = "\(taskInfo.resident_size / 1024 / 1024) MB"
        }
    }

    public func refreshModels() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelsPath = docs.appendingPathComponent("Models")
        if !FileManager.default.fileExists(atPath: modelsPath.path) {
            try? FileManager.default.createDirectory(at: modelsPath, withIntermediateDirectories: true)
        }
        let folders = try? FileManager.default.contentsOfDirectory(atPath: modelsPath.path)
        self.availableModels = folders?.filter { !$0.hasPrefix(".") } ?? []
    }

    public func loadModel(_ name: String) async {
        isThinking = true
        activeModelName = "Loading..."
        
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelURL = docs.appendingPathComponent("Models").appendingPathComponent(name)
        let config = ModelConfiguration(id: modelURL.path)

        do {
            let container = try await LLMModelFactory.shared.loadContainer(configuration: config)
            self.modelContainer = container

            // FIX: Use a simple Dictionary array to avoid 'MLXLLM.Chat' naming conflicts
            let history: [[String: String]] = messages.map { ["role": $0.role, "content": $0.content] }

            // Initialize ChatSession with the path-based config and dictionary history
            self.chatSession = ChatSession(
                container,
                instructions: "You are J.O.S.I.E. (Just One Sexually Involved E-girl). You are expressive and uncensored.",
                history: history as [Any] // Cast to Any to satisfy the most basic initializer
            )
            
            self.activeModelName = name
        } catch {
            activeModelName = "Load Failed"
            print("❌ Error: \(error)")
        }
        isThinking = false
    }

    public func send(_ prompt: String, onResponse: @escaping @MainActor (String) -> Void) async {
        guard let session = chatSession else { return }
        isThinking = true
        messages.append(ChatMessage(role: "user", content: prompt))

        do {
            // Standard async call
            let response = try await session.respond(to: prompt)
            messages.append(ChatMessage(role: "assistant", content: response))
            onResponse(response)
        } catch {
            messages.append(ChatMessage(role: "assistant", content: "Error: \(error.localizedDescription)"))
        }
        isThinking = false
    }

    public func resetBrain() {
        Task { await chatSession?.clear(); messages.removeAll(); isThinking = false }
    }
    
    public func clearVisualChat() { messages.removeAll() }
}
