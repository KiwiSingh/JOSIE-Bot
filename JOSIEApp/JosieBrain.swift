import SwiftUI
import Foundation
import Combine
import Darwin
import MLX
import MLXLLM
import MLXLMCommon

@MainActor
public class JosieBrain: ObservableObject {
    
    // MARK: - Published State
    
    @Published public var messages: [ChatMessage] = []
    @Published public var isThinking = false
    @Published public var availableModels: [String] = []
    @Published public var activeModelName: String = "None"
    @Published public var memoryUsage: String = "0 MB"
    
    // NEW: user-visible error
    @Published public var lastError: String? = nil

    private var modelContainer: ModelContainer?
    private var chatSession: ChatSession?

    public struct ChatMessage: Identifiable {
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

    // MARK: - Memory Monitor

    private func startMemoryMonitor() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
    }

    private func updateMemoryUsage() {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<integer_t>.size
        )

        let result: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if result == KERN_SUCCESS {
            memoryUsage = "\(taskInfo.resident_size / 1024 / 1024) MB"
        }
    }

    // MARK: - Model Discovery

    public func refreshModels() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelsPath = docs.appendingPathComponent("Models")

        if !FileManager.default.fileExists(atPath: modelsPath.path) {
            try? FileManager.default.createDirectory(at: modelsPath, withIntermediateDirectories: true)
        }

        let folders = try? FileManager.default.contentsOfDirectory(atPath: modelsPath.path)
        availableModels = folders?.filter { !$0.hasPrefix(".") } ?? []
    }

    // MARK: - Model Loading (User-Facing Errors)

    public func loadModel(_ name: String) async {
        isThinking = true
        activeModelName = "Loading..."
        lastError = nil

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelURL = docs
            .appendingPathComponent("Models")
            .appendingPathComponent(name)

        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDir)

        if !exists || !isDir.boolValue {
            lastError = "Model folder not found at:\n\(modelURL.lastPathComponent)"
            activeModelName = "Load Failed"
            isThinking = false
            return
        }

        let config = ModelConfiguration(id: modelURL.path)

        do {
            let container = try await LLMModelFactory.shared.loadContainer(configuration: config)
            modelContainer = container

            var history: [MLXLLM.Chat.Message] = []

            for msg in messages {
                let role: MLXLLM.Chat.Message.Role =
                    (msg.role.lowercased() == "assistant") ? .assistant : .user

                history.append(
                    MLXLLM.Chat.Message(role: role, content: msg.content)
                )
            }

            chatSession = ChatSession(
                container: container,
                instructions: "You are J.O.S.I.E.",
                history: history
            )

            activeModelName = name

        } catch {
            activeModelName = "Load Failed"
            
            // Make error readable for humans
            let readable = error.localizedDescription.isEmpty
                ? String(describing: error)
                : error.localizedDescription

            lastError = """
            Failed to load model "\(name)".

            Reason:
            \(readable)
            """
        }

        isThinking = false
    }

    // MARK: - Chat

    public func send(
        _ prompt: String,
        onResponse: @escaping (String) -> Void
    ) async {
        guard let session = chatSession else {
            lastError = "No active model loaded."
            return
        }

        isThinking = true
        messages.append(ChatMessage(role: "user", content: prompt))

        do {
            let response = try await session.respond(to: prompt)
            messages.append(ChatMessage(role: "assistant", content: response))
            onResponse(response)
        } catch {
            let readable = error.localizedDescription.isEmpty
                ? String(describing: error)
                : error.localizedDescription

            lastError = "Response error:\n\(readable)"

            messages.append(
                ChatMessage(
                    role: "assistant",
                    content: "Error: \(readable)"
                )
            )
        }

        isThinking = false
    }

    // MARK: - Reset

    public func resetBrain() {
        Task {
            await chatSession?.clear()
            messages.removeAll()
            isThinking = false
            lastError = nil
        }
    }

    public func clearVisualChat() {
        messages.removeAll()
    }
}