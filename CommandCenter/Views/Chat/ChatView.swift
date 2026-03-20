import SwiftUI

struct ChatView: View {
    @State private var chatService = ChatService()
    @State private var messageText = ""
    @State private var showScrollToBottom = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppColors.backgroundGradient

                VStack(spacing: 0) {
                    // Messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(groupedMessages.enumerated()), id: \.element.id) { index, item in
                                    switch item {
                                    case .dateHeader(let label, let id):
                                        dateSeparator(label)
                                            .id(id)
                                    case .message(let msg, let isGrouped, let isDelivered):
                                        MessageBubble(
                                            message: msg,
                                            isGrouped: isGrouped,
                                            isDelivered: isDelivered
                                        )
                                        .id(msg.id)
                                        .transition(.asymmetric(
                                            insertion: .move(edge: .bottom).combined(with: .opacity),
                                            removal: .opacity
                                        ))
                                    }
                                }

                                if chatService.isTyping {
                                    typingIndicator
                                        .id("typing")
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .animation(.easeOut(duration: 0.25), value: chatService.messages.count)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .refreshable {
                            await chatService.loadHistory()
                        }
                        .onChange(of: chatService.messages.count) {
                            scrollToBottom(proxy: proxy)
                        }
                        .onChange(of: chatService.isTyping) {
                            if chatService.isTyping {
                                scrollToBottom(proxy: proxy)
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if showScrollToBottom {
                                Button {
                                    HapticHelper.light()
                                    scrollToBottom(proxy: proxy)
                                } label: {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(AppColors.accent)
                                        .padding(12)
                                        .background(AppColors.card.opacity(0.9), in: Circle())
                                }
                                .padding(.trailing, 12)
                                .padding(.bottom, 8)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }

                    // Quick reply chips
                    if !quickReplies.isEmpty && messageText.isEmpty {
                        QuickReplyChips(suggestions: quickReplies) { text in
                            sendMessage(text)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeOut(duration: 0.2), value: quickReplies)
                        .padding(.bottom, 4)
                    }

                    // Slash command menu
                    if !matchingCommands.isEmpty {
                        SlashCommandMenu(commands: matchingCommands) { cmd in
                            messageText = ""
                            sendMessage(cmd.prompt)
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .animation(.easeOut(duration: 0.2), value: matchingCommands.count)
                        .padding(.bottom, 4)
                    }

                    // Input bar
                    ChatInputBar(text: $messageText) {
                        // Check if it's a slash command
                        if let cmd = SlashCommand.all.first(where: { $0.command == messageText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }) {
                            messageText = ""
                            sendMessage(cmd.prompt)
                        } else {
                            let text = messageText
                            messageText = ""
                            sendMessage(text)
                        }
                    }
                }
            }
            .navigationTitle("Denny 🦩")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task {
            await chatService.loadHistory()
            chatService.startPolling()
        }
        .onDisappear {
            chatService.stopPolling()
        }
    }

    // MARK: - Slash Commands

    private var matchingCommands: [SlashCommand] {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return [] }
        return SlashCommand.matching(trimmed)
    }

    // MARK: - Quick Replies

    private var quickReplies: [String] {
        guard !chatService.isTyping else { return [] }
        let lastAssistant = chatService.visibleMessages.last(where: { !$0.isUser })
        return QuickReplyChips.suggestions(for: lastAssistant)
    }

    // MARK: - Grouped Messages with Date Headers

    private enum ChatItem: Identifiable {
        case dateHeader(String, String)
        case message(Message, isGrouped: Bool, isDelivered: Bool)

        var id: String {
            switch self {
            case .dateHeader(_, let id): return id
            case .message(let msg, _, _): return msg.id
            }
        }
    }

    private var groupedMessages: [ChatItem] {
        let visible = chatService.visibleMessages
        var items: [ChatItem] = []
        var lastDateLabel: String?

        for (i, msg) in visible.enumerated() {
            // Insert date header when the day changes
            if let header = msg.dateHeader, header != lastDateLabel {
                items.append(.dateHeader(header, "date-\(header)-\(i)"))
                lastDateLabel = header
            }

            // Grouping: is the NEXT message from the same role and within 60 seconds?
            let isGrouped: Bool = {
                guard i + 1 < visible.count else { return false }
                let next = visible[i + 1]
                guard next.role == msg.role else { return false }
                if let d1 = msg.parsedDate, let d2 = next.parsedDate {
                    return d2.timeIntervalSince(d1) < 60
                }
                return false
            }()

            let isDelivered = !chatService.isOptimistic(msg)

            items.append(.message(msg, isGrouped: isGrouped, isDelivered: isDelivered))
        }

        return items
    }

    // MARK: - Subviews

    private func dateSeparator(_ label: String) -> some View {
        HStack {
            line
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColors.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(AppColors.card.opacity(0.6), in: Capsule())
            line
        }
        .padding(.vertical, 12)
    }

    private var line: some View {
        Rectangle()
            .fill(AppColors.border.opacity(0.4))
            .frame(height: 0.5)
    }

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            Text("🦩")
                .font(.title3)
                .padding(.bottom, 2)

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    BouncingDot(delay: Double(i) * 0.15)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppColors.card, in: BubbleShape(isUser: false, hasTail: true))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 6)
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            let target = chatService.isTyping ? "typing" : (chatService.visibleMessages.last?.id ?? "typing")
            proxy.scrollTo(target, anchor: .bottom)
        }
    }

    private func sendMessage(_ text: String) {
        HapticHelper.light()
        Task {
            await chatService.send(text)
        }
    }
}

// MARK: - Bouncing Dot Animation

struct BouncingDot: View {
    let delay: Double
    @State private var animating = false

    var body: some View {
        Circle()
            .fill(AppColors.muted)
            .frame(width: 7, height: 7)
            .offset(y: animating ? -4 : 2)
            .animation(
                .easeInOut(duration: 0.45)
                .repeatForever(autoreverses: true)
                .delay(delay),
                value: animating
            )
            .onAppear { animating = true }
    }
}
