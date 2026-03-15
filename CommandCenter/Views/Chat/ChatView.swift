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
                        .refreshable {
                            await chatService.loadHistory()
                        }
                        .onChange(of: chatService.messages.count) {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(chatService.visibleMessages.last?.id ?? "typing", anchor: .bottom)
                            }
                        }
                        .overlay(alignment: .bottomTrailing) {
                            if showScrollToBottom {
                                Button {
                                    HapticHelper.light()
                                    withAnimation {
                                        proxy.scrollTo(chatService.visibleMessages.last?.id ?? "typing", anchor: .bottom)
                                    }
                                } label: {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.title2)
                                        .foregroundStyle(AppColors.accent)
                                        .padding(12)
                                        .glassCard(cornerRadius: 20)
                                }
                                .padding(.trailing, 12)
                                .padding(.bottom, 8)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }

                    // Input bar
                    ChatInputBar(text: $messageText) {
                        let text = messageText
                        messageText = ""
                        HapticHelper.light()
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
