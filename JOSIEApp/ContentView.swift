import SwiftUI

struct ContentView: View {

    @StateObject private var brain = JosieBrain()
    @StateObject private var voiceManager = JosieVoiceManager()
    @State private var messages: [(text: String, isUser: Bool)] = []
    @State private var inputText = ""
    @State private var selectedModel = ""
    @State private var availableModels: [String] = []
    @State private var showModelPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                header

                Divider()

                chatArea
            }
            .navigationBarHidden(true)
            .safeAreaInset(edge: .bottom) {
                inputBar
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Hide") {
                        hideKeyboard()
                    }
                }
            }
            .sheet(isPresented: $showModelPicker) {
                ModelPickerView(
                    selectedModel: $selectedModel,
                    models: availableModels
                )
            }
            .task {
                let models = brain.availableLocalModels()
                availableModels = models
                if selectedModel.isEmpty, let first = models.first {
                    selectedModel = first
                }
            }
            .onChange(of: selectedModel) { _, newValue in
                guard !newValue.isEmpty else { return }
                Task {
                    await brain.loadModel(modelName: newValue)
                }
            }
            .onChange(of: voiceManager.lastTranscript) { _, newValue in
                guard voiceManager.isListening else { return }
                inputText = newValue
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image("josie_avatar")
                .resizable()
                .scaledToFill()
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .accessibilityLabel("JOSIE")

            VStack(alignment: .leading, spacing: 1) {
                Text("JOSIE")
                    .font(.headline)
                    .lineLimit(1)

                Text(brain.currentModelName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 6) {
                Text(String(format: "RAM %.0f MB", brain.memoryUsageMB))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)

                if voiceManager.voiceEnabled {
                    Label("Voice On", systemImage: "waveform.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.blue)
                        .accessibilityLabel("Voice On")
                }
            }

            Button("Models") {
                availableModels = brain.availableLocalModels()
                showModelPicker = true
            }
            .font(.caption2)

            Menu {
                Section("Voice") {
                    Toggle("Voice On", isOn: $voiceManager.voiceEnabled)
                }

                Section("Memory") {
                    Toggle("Low Memory", isOn: $brain.lowMemoryMode)
                    Text(String(format: "Max %.0f MB", brain.maxMemoryMB))
                }

                Section("Model") {
                    Text(brain.currentModelName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.caption)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
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
            .scrollDismissesKeyboard(.interactively)
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
        HStack(alignment: .bottom, spacing: 8) {
            Button {
                hideKeyboard()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.title3)
            }
            .buttonStyle(.borderless)

            Button {
                voiceManager.toggleListening { transcript in
                    inputText = transcript
                    sendMessage()
                }
            } label: {
                Image(systemName: voiceManager.isListening ? "mic.fill" : "mic")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .disabled(!voiceManager.voiceEnabled)
            .accessibilityLabel(voiceManager.isListening ? "Stop Listening" : "Start Listening")

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
            .disabled(
                inputText.trimmingCharacters(in: .whitespaces).isEmpty ||
                brain.isGenerating ||
                brain.isLoading
            )
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
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
            voiceManager.speak(reply)
        }
    }
}
