import SwiftUI

struct ChatBubble: View {
    let message: String
    let isUser: Bool

    @State private var isExpanded = false
    @State private var isTruncated = false

    var body: some View {
        HStack(alignment: .bottom) {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 6) {
                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .lineLimit(isUser || isExpanded ? nil : 4)
                    .fixedSize(horizontal: false, vertical: true)
                    .background(
                        TruncationDetector(
                            text: message,
                            lineLimit: 4,
                            isActive: !isUser && !isExpanded,
                            isTruncated: $isTruncated
                        )
                    )

                if !isUser && !isExpanded && isTruncated {
                    Button("See more") {
                        isExpanded = true
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
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

private struct TruncationDetector: View {
    let text: String
    let lineLimit: Int
    let isActive: Bool
    @Binding var isTruncated: Bool

    var body: some View {
        GeometryReader { limitedProxy in
            Text(text)
                .font(.body)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .background(
                    GeometryReader { fullProxy in
                        Color.clear
                            .onAppear {
                                updateTruncation(limited: limitedProxy.size, full: fullProxy.size)
                            }
                            .onChange(of: text) { _, _ in
                                updateTruncation(limited: limitedProxy.size, full: fullProxy.size)
                            }
                    }
                )
                .hidden()
        }
        .frame(height: 0)
    }

    private func updateTruncation(limited: CGSize, full: CGSize) {
        guard isActive else {
            isTruncated = false
            return
        }

        let truncated = full.height > limited.height + 1
        if truncated != isTruncated {
            isTruncated = truncated
        }
    }
}
