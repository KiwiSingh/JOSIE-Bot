import SwiftUI
import Foundation
import MLX
import MLXLLM
import MLXLMCommon

@MainActor
@Observable
public class JosieBrain {

    // MARK: - Public State

    public var messages: [ChatMessage] = []
    public var isThinking = false
    public var availableModels: [String] = []
    public var activeModelName: String = "None"
    public var memoryUsage: String = "0 MB"
    public var lastError: String? = nil

    // MARK: - MLX Internals

    private var modelContainer: ModelContainer?
    private var chatSession: ChatSession?

    // MARK: - Chat Message Model

    public struct ChatMessage: Identifiable, Sendable {
        public let id = UUID()
        public let role: String
        public let content: String

        public init(role: String, content: String) {
            self.role = role
            self.content = content
        }
    }

    // MARK: - Init

    public init() {
        startMemoryMonitor()
    }

    // MARK: - Memory Monitor

    private func startMemoryMonitor() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryUsage()
            }
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

    // MARK: - Model Loading (Modern MLX)

    public func loadModel(_ name: String) async {
        isThinking = true
        activeModelName = "Loading..."
        lastError = nil

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelURL = docs
            .appendingPathComponent("Models")
            .appendingPathComponent(name)

        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            activeModelName = "Load Failed"
            lastError = "Model folder not found at:\n\(modelURL.path)"
            isThinking = false
            return
        }

        do {
            let container = try await LLMModelFactory.shared.loadContainer(
                directory: modelURL
            )

            modelContainer = container
            chatSession = ChatSession(container)

            activeModelName = name

        } catch {
            activeModelName = "Load Failed"

            let readable = error.localizedDescription.isEmpty
                ? String(describing: error)
                : error.localizedDescription

            lastError = """
            Failed to load model "\(name)"

            \(readable)
            """
        }

        isThinking = false
    }

    // MARK: - Chat

    public func send(
        _ prompt: String,
        onResponse: @escaping @MainActor (String) -> Void
    ) async {

        guard let session = chatSession else {
            lastError = "No model loaded."
            return
        }

        isThinking = true
        messages.append(ChatMessage(role: "user", content: prompt))

        do {
            let response = try await session.respond(to: prompt)

            messages.append(
                ChatMessage(role: "assistant", content: response)
            )

            onResponse(response)

        } catch {
            let readable = error.localizedDescription.isEmpty
                ? String(describing: error)
                : error.localizedDescription

            messages.append(
                ChatMessage(
                    role: "assistant",
                    content: "Error: \(readable)"
                )
            )

            lastError = readable
        }

        isThinking = false
    }

    // MARK: - Reset

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
