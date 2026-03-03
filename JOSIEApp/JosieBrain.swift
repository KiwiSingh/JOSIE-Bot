import Foundation
import SwiftUI
import MLX
import MLXLLM
import MLXLMCommon

@MainActor
final class JosieBrain: ObservableObject {

    // MARK: - Published UI State

    @Published var messages: [ChatMessage] = []
    @Published var isThinking: Bool = false
    @Published var availableModels: [String] = []
    @Published var activeModelName: String = "None"
    @Published var memoryUsage: String = "0 MB"
    @Published var lastError: String? = nil

    // MARK: - MLX

    private var container: ModelContainer?
    private var session: ChatSession?

    // MARK: - Message Model

    struct ChatMessage: Identifiable {
        let id = UUID()
        let role: String
        let content: String
    }

    // MARK: - Init

    init() {
        startMemoryMonitor()
    }

    // MARK: - RAM Monitor

    private func startMemoryMonitor() {
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMemoryUsage()
            }
        }
    }

    private func updateMemoryUsage() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if result == KERN_SUCCESS {
            memoryUsage = "\(info.resident_size / 1024 / 1024) MB"
        }
    }

    // MARK: - Model Discovery

    func refreshModels() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelsDir = docs.appendingPathComponent("Models")

        if !FileManager.default.fileExists(atPath: modelsDir.path) {
            try? FileManager.default.createDirectory(at: modelsDir, withIntermediateDirectories: true)
        }

        let folders = try? FileManager.default.contentsOfDirectory(atPath: modelsDir.path)
        availableModels = folders?.filter { !$0.hasPrefix(".") } ?? []
    }

    // MARK: - Load Model

    func loadModel(_ name: String) async {
        isThinking = true
        lastError = nil
        activeModelName = "Loading..."

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let modelURL = docs.appendingPathComponent("Models").appendingPathComponent(name)

        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            activeModelName = "Load Failed"
            lastError = "Model folder not found:\n\(modelURL.path)"
            isThinking = false
            return
        }

        do {
            container = try await LLMModelFactory.shared.loadContainer(
                directory: modelURL
            )

            session = ChatSession(container!)
            activeModelName = name

        } catch {
            activeModelName = "Load Failed"
            lastError = """
            Failed to load "\(name)"

            \(error.localizedDescription)
            """
        }

        isThinking = false
    }

    // MARK: - Send Prompt

    func send(_ prompt: String, onResponse: @escaping (String) -> Void) async {
        guard let session else {
            lastError = "No model loaded."
            return
        }

        isThinking = true
        messages.append(ChatMessage(role: "user", content: prompt))

        do {
            let reply = try await session.respond(to: prompt)

            messages.append(ChatMessage(role: "assistant", content: reply))
            onResponse(reply)

        } catch {
            let err = error.localizedDescription
            messages.append(ChatMessage(role: "assistant", content: "Error: \(err)"))
            lastError = err
        }

        isThinking = false
    }

    // MARK: - Reset

    func resetBrain() {
        session = nil
        container = nil
        messages.removeAll()
        activeModelName = "None"
        lastError = nil
    }

    func clearVisualChat() {
        messages.removeAll()
    }
}
