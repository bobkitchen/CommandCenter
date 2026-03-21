import SwiftUI
#if os(macOS)
import UniformTypeIdentifiers
#endif

struct ChatView: View {
    @State private var chatService = ChatService()
    @State private var messageText = ""
    @State private var showScrollToBottom = false
    @State private var showSearch = false
    @State private var searchText = ""
    @State private var searchIndex = 0
    @State private var showAttachmentPicker = false
    @State private var attachedImageData: Data?
    @State private var attachedFileName: String?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                AppColors.backgroundGradient

                VStack(spacing: 0) {
                    // Search bar
                    if showSearch {
                        ChatSearchBar(
                            searchText: $searchText,
                            resultCount: searchResults.count,
                            currentIndex: searchIndex,
                            onPrevious: {
                                if searchIndex > 0 { searchIndex -= 1 }
                            },
                            onNext: {
                                if searchIndex < searchResults.count - 1 { searchIndex += 1 }
                            },
                            onDismiss: {
                                withAnimation {
                                    showSearch = false
                                    searchText = ""
                                }
                            }
                        )
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }

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
                        #if os(iOS)
                        .scrollDismissesKeyboard(.immediately)
                        .onTapGesture {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        #endif
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
                        .onChange(of: searchIndex) {
                            if !searchResults.isEmpty, searchIndex < searchResults.count {
                                scrollToMessage(searchResults[searchIndex].id, proxy: proxy)
                            }
                        }
                        .onChange(of: searchText) {
                            searchIndex = 0
                            if !searchResults.isEmpty {
                                scrollToMessage(searchResults[0].id, proxy: proxy)
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

                    // Attachment preview
                    if attachedImageData != nil || attachedFileName != nil {
                        AttachmentPreview(
                            imageData: attachedImageData,
                            fileName: attachedFileName,
                            onRemove: {
                                attachedImageData = nil
                                attachedFileName = nil
                            }
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    // Attachment picker
                    #if os(iOS)
                    if showAttachmentPicker {
                        ChatAttachmentPicker(
                            selectedImageData: $attachedImageData,
                            selectedFileName: $attachedFileName,
                            isPresented: $showAttachmentPicker
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    #endif

                    // Input bar
                    ChatInputBar(text: $messageText, onAttach: {
                        HapticHelper.light()
                        #if os(iOS)
                        withAnimation { showAttachmentPicker.toggle() }
                        #elseif os(macOS)
                        openMacFilePicker()
                        #endif
                    }) {
                        // Handle attachments
                        if attachedImageData != nil {
                            let text = messageText.isEmpty ? "📷 [Sent a photo]" : messageText
                            messageText = ""
                            attachedImageData = nil
                            attachedFileName = nil
                            showAttachmentPicker = false
                            sendMessage(text)
                        } else if let fileName = attachedFileName {
                            let text = messageText.isEmpty ? "📎 [Attached: \(fileName)]" : messageText
                            messageText = ""
                            attachedImageData = nil
                            attachedFileName = nil
                            showAttachmentPicker = false
                            sendMessage(text)
                        } else if let cmd = SlashCommand.all.first(where: { $0.command == messageText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }) {
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
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 1) {
                        Text("Denny 🦩")
                            .font(.headline)
                            .foregroundStyle(AppColors.text)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(transportColor)
                                .frame(width: 6, height: 6)
                            Text(chatService.transport.rawValue)
                                .font(.caption2)
                                .foregroundStyle(AppColors.muted)
                        }
                    }
                }
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            HapticHelper.light()
                            withAnimation { showSearch.toggle() }
                            if !showSearch { searchText = "" }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                                .foregroundStyle(showSearch ? AppColors.accent : AppColors.muted)
                        }

                        if chatService.transport == .polling {
                            Button {
                                HapticHelper.light()
                                chatService.reconnectWebSocket()
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.muted)
                            }
                        }
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    HStack(spacing: 12) {
                        Button {
                            HapticHelper.light()
                            withAnimation { showSearch.toggle() }
                            if !showSearch { searchText = "" }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .font(.caption)
                                .foregroundStyle(showSearch ? AppColors.accent : AppColors.muted)
                        }

                        if chatService.transport == .polling {
                            Button {
                                HapticHelper.light()
                                chatService.reconnectWebSocket()
                            } label: {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.muted)
                            }
                        }
                    }
                }
                #endif
            }
        }
        .task {
            await chatService.start()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                chatService.resume()
            }
        }
    }

    // MARK: - Transport

    private var transportColor: Color {
        switch chatService.transport {
        case .websocket: return AppColors.success
        case .polling: return AppColors.warning
        case .connecting: return AppColors.muted
        }
    }

    // MARK: - Search

    private var searchResults: [Message] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        return chatService.visibleMessages.filter {
            $0.cleanedContent.lowercased().contains(query)
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

    private func scrollToMessage(_ id: String, proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo(id, anchor: .center)
        }
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

    #if os(macOS)
    private func openMacFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.image, .text, .pdf, .json, .plainText]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let isImage = ["png", "jpg", "jpeg", "gif", "webp", "heic"].contains(url.pathExtension.lowercased())
            if isImage, let data = try? Data(contentsOf: url) {
                attachedImageData = data
                attachedFileName = nil
            } else {
                attachedFileName = url.lastPathComponent
                attachedImageData = nil
            }
        }
    }
    #endif
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
