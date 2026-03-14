import SwiftUI

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isUser { Spacer(minLength: 60) }

            if !message.isUser {
                Text("🦩")
                    .font(.title3)
                    .padding(.bottom, 2)
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 4) {
                bubbleContent
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .if(message.isUser) { view in
                        view
                            .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .if(!message.isUser) { view in
                        view
                            .glassCard(cornerRadius: 18)
                    }

                Text(message.displayTime)
                    .font(.caption2)
                    .foregroundStyle(AppColors.muted)
                    .padding(.horizontal, 4)
            }

            if !message.isUser { Spacer(minLength: 60) }
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if message.isUser {
            Text(message.cleanedContent)
                .font(.body)
                .foregroundStyle(.white)
        } else {
            MarkdownText(message.cleanedContent)
        }
    }
}

// MARK: - Conditional View Modifier

extension View {
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
