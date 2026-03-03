import SwiftUI

struct ContentView: View {

    @StateObject private var brain = JosieBrain()
    @State private var messages: [(text: String, isUser: Bool)] = []
    @State private var inputText = ""
    @State private var selectedModel = "mlx-community/Llama-3.2-1B-Instruct-4bit"
    @State private var showModelPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                header

                Divider()

                chatArea

                Divider()

                inputBar
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showModelPicker) {
                ModelPickerView(
                    selectedModel: $selectedModel,
                    models: [
                        "mlx-community/Llama-3.2-1B-Instruct-4bit",
                        "mlx-community/Gemma-2B-4bit"
                    ]
                )
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("JOSIE")
                    .font(.title2.bold())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Text(selectedModel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.0f MB", brain.memoryUsageMB))
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)

                Button("Models") {
                    showModelPicker = true
                }
                .font(.caption)
            }
        }
        .padding()
    }

    // MARK: - Chat Area

    private var chatArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(messages.enumerated()), id: \.offset) { index, message in
                        ChatBubble(
                            message: message.text,
                            isUser: message.isUser
                        )
                        .id(index)
                    }
                }
                .padding(.vertical)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.indices.last {
                    withAnimation {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(alignment: .bottom) {
            TextField("Message...", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)

            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || brain.isGenerating)
        }
        .padding()
        .background(.ultraThinMaterial)
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    // MARK: - Actions

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append((trimmed, true))
        inputText = ""

        Task {
            let reply = await brain.generate(prompt: trimmed)
            messages.append((reply, false))
        }
    }
}
