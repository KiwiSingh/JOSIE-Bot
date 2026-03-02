import SwiftUI

struct ChatBubble: View {
    let msg: JosieBrain.ChatMessage

    var body: some View {
        HStack {
            if msg.role == "user" { Spacer() }
            
            Text(msg.content)
                .padding(12)
                .background(
                    // J.O.S.I.E. Theme: Pink for user, Dark Glass for J.O.S.I.E.
                    msg.role == "user" ? Color.pink.opacity(0.8) : Color.white.opacity(0.1)
                )
                // 2026 FIX: Use clipShape instead of cornerRadius
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .foregroundColor(.white)
                // Align multiline text within the bubble
                .multilineTextAlignment(msg.role == "user" ? .trailing : .leading)
                .frame(maxWidth: 280, alignment: msg.role == "user" ? .trailing : .leading)
            
            if msg.role == "assistant" { Spacer() }
        }
    }
}
