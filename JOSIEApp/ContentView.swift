import SwiftUI

struct ContentView: View {
    // 2026 UPDATE: @State works for @Observable classes
    @State private var brain = JosieBrain()
    @State private var voice = JosieVoiceManager()
    @State private var input = ""
    @State private var showPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Uses the hex extension we fixed in Extensions.swift
                Color(hex: "#0D0D0D").ignoresSafeArea()

                VStack(spacing: 0) {
                    // Header Section
                    headerView

                    // Chat Scroll
                    ScrollViewReader { proxy in
                        List(brain.messages) { msg in
                            ChatBubble(msg: msg)
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .id(msg.id)
                        }
                        .listStyle(.plain)
                        // iOS 17+ / 2026 Syntax: onChange no longer needs the parameter if using count
                        .onChange(of: brain.messages.count) {
                            withAnimation {
                                proxy.scrollTo(brain.messages.last?.id, anchor: .bottom)
                            }
                        }
                    }

                    // Bottom Controls
                    controlView
                }
            }
            .sheet(isPresented: $showPicker) {
                ModelPickerView(brain: brain)
            }
            .onAppear {
                brain.refreshModels()
            }
        }
    }

    var headerView: some View {
        VStack {
            HStack {
                Button {
                    showPicker = true
                } label: {
                    Image(systemName: "cpu")
                        .foregroundColor(.pink)
                }
                Spacer()
                Button {
                    voice.isMuted.toggle()
                } label: {
                    Image(systemName: voice.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .foregroundColor(voice.isMuted ? .gray : .pink)
                }
            }
            .padding()

            // Ensure "josie_avatar" is in your Assets.xcassets
            Image("josie_avatar")
                .resizable()
                .frame(width: 85, height: 85)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.pink, lineWidth: 2))
                .shadow(color: .pink.opacity(brain.isThinking ? 0.9 : 0.2), radius: 10)

            Text(brain.activeModelName)
                .font(.caption2.monospaced())
                .foregroundColor(.pink)
                .padding(.top, 4)
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

                Button("🧠 Reset Brain") {
                    brain.resetBrain()
                }
                .font(.caption)
                .foregroundColor(.gray)
            }
            .padding(.horizontal)
            .padding(.top, 8)

            HStack(spacing: 12) {
                Button {
                    voice.toggleListening { recognizedText in
                        input = recognizedText
                    }
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

    // Encapsulated send logic to prevent duplication
    private func performSend() {
        guard !input.isEmpty else { return }
        let currentInput = input
        input = ""
        
        Task {
            await brain.send(currentInput) { response in
                // Only speak if not muted
                if !voice.isMuted {
                    voice.speak(response)
                }
            }
        }
    }
}
