import SwiftUI

struct ChatBubble: View {
    let message: String
    let isUser: Bool

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 40) }

            Text(message)
                .font(.body)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 18)
                        .fill(isUser ? Color.blue : Color.gray.opacity(0.2))
                )
                .foregroundStyle(isUser ? .white : .primary)
                .frame(maxWidth: 500, alignment: isUser ? .trailing : .leading)

            if !isUser { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}
