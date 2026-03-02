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
            .onChange(of: brain.messages.count) { _ in
              withAnimation { proxy.scrollTo(brain.messages.last?.id) }
            }
          }

          // Bottom Controls
          controlView
        }
      }
      .sheet(isPresented: $showPicker) { ModelPickerView(brain: brain) }
      .onAppear { brain.refreshModels() }
    }
  }

  var headerView: some View {
    VStack {
      HStack {
        Button {
          showPicker = true
        } label: {
          Image(systemName: "cpu").foregroundColor(.pink)
        }
        Spacer()
        Button {
          voice.isMuted.toggle()
        } label: {
          Image(systemName: voice.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            .foregroundColor(voice.isMuted ? .gray : .pink)
        }
      }.padding()

      Image("josie_avatar")
        .resizable().frame(width: 85, height: 85).clipShape(Circle())
        .overlay(Circle().stroke(Color.pink, lineWidth: 2))
        .shadow(color: .pink.opacity(brain.isThinking ? 0.9 : 0.2), radius: 10)

      Text(brain.activeModelName).font(.caption2.monospaced()).foregroundColor(.pink)
    }
  }

  var controlView: some View {
    VStack {
      HStack {
        Button("🗑️ Clear") { brain.clearVisualChat() }.font(.caption).foregroundColor(.gray)
        Spacer()
        Button("🧠 Reset Brain") { brain.resetBrain() }.font(.caption).foregroundColor(.gray)
      }.padding(.horizontal)

      HStack {
        Button {
          voice.toggleListening { input = $0 }
        } label: {
          Image(systemName: voice.isListening ? "stop.circle.fill" : "mic.fill")
            .foregroundColor(voice.isListening ? .red : .white).font(.title2)
        }

        TextField("Message JOSIE...", text: $input)
          .padding(10).background(Capsule().fill(.white.opacity(0.1))).foregroundColor(.white)

        Button {
          let p = input
          input = ""
          Task { await brain.send(p) { voice.speak($0) } }
        } label: {
          Image(systemName: "arrow.up.circle.fill").font(.title).foregroundColor(.pink)
        }
      }.padding()
    }.background(.black)
  }
}
