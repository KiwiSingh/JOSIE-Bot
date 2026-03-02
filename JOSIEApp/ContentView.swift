import SwiftUI

struct ContentView: View {
    @State private var brain = JosieBrain()
    @State private var voice = JosieVoiceManager()
    @State private var input = ""
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "#0D0D0D").ignoresSafeArea()

                VStack(spacing: 0) {
                    headerView

                    ScrollViewReader { proxy in
                        List(brain.messages) { msg in
                            ChatBubble(msg: msg)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .id(msg.id)
                        }
                        .listStyle(.plain)
                        .onChange(of: brain.messages.count) { _, _ in
                            if let lastId = brain.messages.last?.id {
                                withAnimation {
                                    proxy.scrollTo(lastId, anchor: .bottom)
                                }
                            }
                        }
                    }

                    controlView
                }
            }
            .sheet(isPresented: $showPicker) {
                ModelPickerView(brain: brain)
            }
            .onAppear {
                brain.refreshModels()
            }
            // ✅ NEW: User-facing error alert
            .alert(
                "Model Error",
                isPresented: Binding(
                    get: { brain.lastError != nil },
                    set: { _ in brain.lastError = nil }
                )
            ) {
                Button("OK", role: .cancel) {
                    brain.lastError = nil
                }
            } message: {
                Text(brain.lastError ?? "")
            }
        }
    }

    var headerView: some View {
        VStack {
            HStack {
                Button { showPicker = true } label: {
                    Image(systemName: "cpu")
                        .foregroundColor(.pink)
                }

                Spacer()

                Button { voice.isMuted.toggle() } label: {
                    Image(systemName: voice.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundColor(voice.isMuted ? .gray : .pink)
                }
            }
            .padding()

            Image("josie_avatar")
                .resizable()
                .frame(width: 85, height: 85)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.pink, lineWidth: 2))
                .shadow(color: .pink.opacity(brain.isThinking ? 0.9 : 0.2), radius: 10)

            Text(brain.activeModelName)
                .font(.caption2.monospaced())
                .foregroundColor(.pink)
            
            Text("RAM: \(brain.memoryUsage)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)
        }
    }

    var controlView: some View {
        VStack(spacing: 0) {
            HStack {
                Button("🗑️ Clear") {
                    brain.clearVisualChat()
                }
                .font(.caption)
                .foregroundColor(.gray)

                Spacer()

                Button("🧠 Reset") {
                    brain.resetBrain()
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            HStack(spacing: 12) {
                Button {
                    voice.toggleListening { input = $0 }
                } label: {
                    Image(systemName: voice.isListening ? "stop.circle.fill" : "mic.fill")
                        .foregroundColor(voice.isListening ? .red : .white)
                        .font(.title2)
                }

                TextField("Message JOSIE...", text: $input)
                    .padding(10)
                    .background(Capsule().fill(.white.opacity(0.1)))
                    .foregroundColor(.white)
                    .submitLabel(.send)
                    .onSubmit {
                        performSend()
                    }

                Button {
                    performSend()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title)
                        .foregroundColor(input.isEmpty ? .gray : .pink)
                }
                .disabled(input.isEmpty || brain.isThinking)
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea(edges: .bottom))
    }

    private func performSend() {
        guard !input.isEmpty else { return }

        let prompt = input
        input = ""

        Task {
            await brain.send(prompt) { response in
                if !voice.isMuted {
                    voice.speak(response)
                }
            }
        }
    }
}