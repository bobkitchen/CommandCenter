import SwiftUI

struct MessageBubble: View {
    let message: Message
    /// Whether the next message is from the same sender (for grouping)
    var isGrouped: Bool = false
    /// Whether this message has been confirmed by the server
    var isDelivered: Bool = true

    @State private var showCopied = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 6) {
            if message.isUser { Spacer(minLength: 60) }

            // Avatar — only show on last message of a group
            if !message.isUser {
                if !isGrouped {
                    Text("🦩")
                        .font(.title3)
                        .padding(.bottom, 2)
                } else {
                    // Invisible spacer to keep alignment
                    Text("🦩")
                        .font(.title3)
                        .opacity(0)
                }
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 2) {
                bubbleContent
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(bubbleBackground, in: BubbleShape(isUser: message.isUser, hasTail: !isGrouped))
                    .contextMenu {
                        Button {
                            #if os(iOS)
                            UIPasteboard.general.string = message.cleanedContent
                            #elseif os(macOS)
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.cleanedContent, forType: .string)
                            #endif
                            showCopied = true
                            HapticHelper.light()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                showCopied = false
                            }
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                    }
                    .overlay(alignment: .center) {
                        if showCopied {
                            Text("Copied")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.black.opacity(0.7), in: Capsule())
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.easeOut(duration: 0.2), value: showCopied)

                // Timestamp + delivery status — only on last of group
                if !isGrouped {
                    HStack(spacing: 4) {
                        Text(message.displayTime)
                            .font(.caption2)
                            .foregroundStyle(AppColors.muted)

                        if message.isUser {
                            Image(systemName: isDelivered ? "checkmark.circle.fill" : "checkmark.circle")
                                .font(.caption2)
                                .foregroundStyle(isDelivered ? AppColors.accent : AppColors.muted)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            if !message.isUser { Spacer(minLength: 60) }
        }
        .padding(.bottom, isGrouped ? 1 : 6)
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

    private var bubbleBackground: some ShapeStyle {
        message.isUser ? AnyShapeStyle(AppColors.accent) : AnyShapeStyle(AppColors.card)
    }
}

// MARK: - Bubble Shape with Tail

struct BubbleShape: Shape {
    let isUser: Bool
    let hasTail: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = 6

        var path = Path()

        if hasTail && isUser {
            // User bubble: tail on bottom-right
            path.addRoundedRect(in: CGRect(x: rect.minX, y: rect.minY,
                                           width: rect.width - tailSize, height: rect.height),
                                cornerSize: CGSize(width: radius, height: radius))
            // Tail
            let tailX = rect.maxX - tailSize
            let tailY = rect.maxY - 12
            path.move(to: CGPoint(x: tailX, y: tailY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - 4))
            path.addLine(to: CGPoint(x: tailX, y: tailY + 10))
        } else if hasTail && !isUser {
            // Assistant bubble: tail on bottom-left
            path.addRoundedRect(in: CGRect(x: rect.minX + tailSize, y: rect.minY,
                                           width: rect.width - tailSize, height: rect.height),
                                cornerSize: CGSize(width: radius, height: radius))
            // Tail
            let tailX = rect.minX + tailSize
            let tailY = rect.maxY - 12
            path.move(to: CGPoint(x: tailX, y: tailY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - 4))
            path.addLine(to: CGPoint(x: tailX, y: tailY + 10))
        } else {
            // No tail — simple rounded rect
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: radius, height: radius))
        }

        return path
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
