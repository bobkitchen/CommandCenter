import SwiftUI

struct ChatView: View {
    @State private var chatService = ChatService()
    @State private var messageText = ""
    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGradient

                VStack(spacing: 0) {
                    // Messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(chatService.visibleMessages) { message in
                                    MessageBubble(message: message)
                                        .id(message.id)
                                }

                                if chatService.isTyping {
                                    typingIndicator
                                        .id("typing")
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onAppear { scrollProxy = proxy }
                        .onChange(of: chatService.messages.count) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(chatService.visibleMessages.last?.id ?? "typing", anchor: .bottom)
                            }
                        }
                    }

                    // Input bar
                    ChatInputBar(text: $messageText) {
                        let text = messageText
                        messageText = ""
                        Task {
                            await chatService.send(text)
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

    private var typingIndicator: some View {
        HStack(spacing: 4) {
            Text("🦩")
                .font(.caption)

            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(AppColors.muted)
                        .frame(width: 6, height: 6)
                        .opacity(0.6)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .glassCard(cornerRadius: 16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
