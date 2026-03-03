import Foundation
import MLX
import MLXLLM
import Combine
import MachO

@MainActor
final class JosieBrain: ObservableObject {
    
    // MARK: - Published State
    
    @Published var isLoading: Bool = false
    @Published var isGenerating: Bool = false
    @Published var memoryUsageMB: Double = 0
    @Published var currentModelName: String = "None"
    
    // MARK: - Private
    
    private var modelContainer: ModelContainer?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Init
    
    init() {
        startMemoryMonitor()
    }
    
    // MARK: - Model Loading
    
    func loadModel(modelName: String) async {
        guard !isLoading else { return }
        
        isLoading = true
        currentModelName = modelName
        
        do {
            let configuration = ModelConfiguration(
                model: modelName
            )
            
            modelContainer = try await ModelContainer(
                configuration: configuration
            )
            
            print("✅ Model Loaded:", modelName)
            
        } catch {
            print("❌ Model load failed:", error)
            currentModelName = "Load Failed"
        }
        
        isLoading = false
    }
    
    // MARK: - Text Generation
    
    func generate(
        prompt: String,
        maxTokens: Int = 256,
        temperature: Float = 0.7
    ) async -> String {
        
        guard let modelContainer else {
            return "Model not loaded."
        }
        
        guard !isGenerating else {
            return "Already generating."
        }
        
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            let parameters = GenerateParameters(
                maxTokens: maxTokens,
                temperature: temperature
            )
            
            let result = try await modelContainer.generate(
                prompt: prompt,
                parameters: parameters
            )
            
            return result.output
            
        } catch {
            print("❌ Generation failed:", error)
            return "Generation failed."
        }
    }
    
    // MARK: - Memory Monitoring
    
    private func startMemoryMonitor() {
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.memoryUsageMB = Self.currentMemoryUsage()
            }
            .store(in: &cancellables)
    }
    
    private static func currentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size /
            MemoryLayout<natural_t>.size
        )
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(
                to: integer_t.self,
                capacity: 1
            ) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        if result == KERN_SUCCESS {
            return Double(info.resident_size) / 1024 / 1024
        } else {
            return 0
        }
    }
}
