import SwiftUI
struct ChatBubble: View {
  let msg: JosieBrain.ChatMessage
  var body: some View {
    HStack {
      if msg.role == "user" { Spacer() }
      Text(msg.content)
        .padding(12).background(
          msg.role == "user" ? Color.blue.opacity(0.4) : Color.white.opacity(0.1)
        )
        .cornerRadius(18).foregroundColor(.white).frame(
          maxWidth: 280, alignment: msg.role == "user" ? .trailing : .leading)
      if msg.role == "assistant" { Spacer() }
    }
  }
}
