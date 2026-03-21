import Foundation

/// Transport mode for real-time chat
enum ChatTransport: String {
    case websocket = "WebSocket"
    case polling = "Polling"
    case connecting = "Connecting..."
}

@MainActor @Observable
final class ChatService {
    var messages: [Message] = []
    var isTyping = false
    var error: String?
    var transport: ChatTransport = .connecting

    private var pollTask: Task<Void, Never>?
    private var wsTask: Task<Void, Never>?
    private var optimisticIds: Set<String> = []
    private var webSocketTask: URLSessionWebSocketTask?
    private var wsRetryCount = 0
    private let maxWsRetries = 3
    private var lastSendTime: Date?

    var visibleMessages: [Message] {
        messages.filter { !$0.isHidden }
    }

    // MARK: - Lifecycle

    func start() async {
        await loadHistory()
        await connectWebSocket()
    }

    func stop() {
        stopPolling()
        disconnectWebSocket()
    }

    // MARK: - WebSocket

    private func connectWebSocket() async {
        guard let baseURL = getBaseURL() else {
            startPolling()
            return
        }

        // Convert http(s) to ws(s)
        let wsURL = baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")

        guard let url = URL(string: "\(wsURL)/api/chat/ws") else {
            startPolling()
            return
        }

        transport = .connecting
        disconnectWebSocket()

        // Use the shared cookie storage so auth cookies are sent with the upgrade request
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpShouldSetCookies = true
        let session = URLSession(configuration: config)

        let ws = session.webSocketTask(with: url)
        webSocketTask = ws
        ws.resume()

        // Start listening in a background task
        wsTask = Task { [weak self] in
            // Give the connection a moment to establish
            try? await Task.sleep(for: .milliseconds(500))

            // Test the connection with a ping
            do {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    ws.sendPing { error in
                        if let error { cont.resume(throwing: error) }
                        else { cont.resume() }
                    }
                }
                await MainActor.run {
                    self?.transport = .websocket
                    self?.wsRetryCount = 0
                    self?.stopPolling() // WebSocket is live, stop polling
                }
                print("[Chat] WebSocket connected")
                await self?.wsListenLoop(ws)
            } catch {
                print("[Chat] WebSocket ping failed: \(error.localizedDescription)")
                await self?.handleWebSocketDisconnect()
            }
        }
    }

    private func wsListenLoop(_ ws: URLSessionWebSocketTask) async {
        while !Task.isCancelled && ws.state == .running {
            do {
                let message = try await ws.receive()
                switch message {
                case .string(let text):
                    await handleWebSocketMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        await handleWebSocketMessage(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                print("[Chat] WebSocket receive error: \(error.localizedDescription)")
                break
            }
        }

        // Connection dropped — try to reconnect
        if !Task.isCancelled {
            await handleWebSocketDisconnect()
        }
    }

    private func handleWebSocketMessage(_ text: String) async {
        guard let data = text.data(using: .utf8) else { return }

        // Try to decode different message types the server might send
        // Type 1: A full messages array update
        if let response = try? JSONDecoder().decode(WSMessagesPayload.self, from: data) {
            mergeMessages(server: response.messages)
            if let typing = response.typing {
                isTyping = typing
            }
            return
        }

        // Type 2: A single new message
        if let msg = try? JSONDecoder().decode(WSNewMessage.self, from: data) {
            if msg.type == "message", let message = msg.message {
                // Append if we don't already have it
                if !messages.contains(where: { $0.id == message.id }) {
                    messages.append(message)
                }
                // If it's an assistant message, clear typing
                if message.role == "assistant" {
                    isTyping = false
                }
            } else if msg.type == "typing" {
                isTyping = msg.typing ?? false
            }
            return
        }

        // Type 3: Simple typing indicator
        if let status = try? JSONDecoder().decode(WSTypingPayload.self, from: data) {
            isTyping = status.typing
            return
        }

        print("[Chat] Unknown WebSocket message: \(text.prefix(200))")
    }

    private func handleWebSocketDisconnect() async {
        disconnectWebSocket()
        wsRetryCount += 1

        if wsRetryCount <= maxWsRetries {
            // Exponential backoff: 1s, 2s, 4s
            let delay = UInt64(pow(2.0, Double(wsRetryCount - 1)))
            print("[Chat] WebSocket reconnecting in \(delay)s (attempt \(wsRetryCount)/\(maxWsRetries))")
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled else { return }
            await connectWebSocket()
        } else {
            // Give up on WebSocket, fall back to polling
            print("[Chat] WebSocket failed after \(maxWsRetries) attempts, falling back to polling")
            startPolling()
        }
    }

    private func disconnectWebSocket() {
        wsTask?.cancel()
        wsTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    /// Send a message via WebSocket if connected
    private func sendViaWebSocket(_ text: String) -> Bool {
        guard let ws = webSocketTask, ws.state == .running else { return false }

        let payload: [String: Any] = ["type": "message", "content": text]
        guard let data = try? JSONSerialization.data(withJSONObject: payload),
              let jsonString = String(data: data, encoding: .utf8) else { return false }

        Task {
            do {
                try await ws.send(.string(jsonString))
            } catch {
                print("[Chat] WebSocket send failed: \(error.localizedDescription)")
            }
        }
        return true
    }

    // MARK: - Polling (fallback)

    func startPolling() {
        guard pollTask == nil else { return }
        transport = .polling
        print("[Chat] Starting polling fallback")
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                let interval = self?.adaptivePollInterval ?? 3.0
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await self?.loadHistory()
                await self?.checkTyping()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    /// Adaptive polling: faster when waiting for a reply, slower when idle
    private var adaptivePollInterval: Double {
        // If user sent a message in the last 30s, poll fast (waiting for reply)
        if let lastSend = lastSendTime,
           Date().timeIntervalSince(lastSend) < 30 {
            return 1.0
        }
        // If typing indicator is on, poll fast
        if isTyping {
            return 1.0
        }
        // Normal interval
        return 3.0
    }

    // MARK: - Load & Send

    func loadHistory() async {
        do {
            let response: MessagesResponse = try await APIClient.shared.get(
                "/api/chat/history",
                queryItems: [URLQueryItem(name: "limit", value: "200")]
            )
            mergeMessages(server: response.messages)
        } catch {
            self.error = error.localizedDescription
        }
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Optimistic local add
        let optimisticId = "opt-\(stableHash(role: "user", content: trimmed))"
        let tempMessage = Message(
            id: optimisticId,
            role: "user",
            content: trimmed,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            channel: "ios"
        )
        optimisticIds.insert(optimisticId)
        messages.append(tempMessage)
        isTyping = true
        lastSendTime = Date()

        // Try WebSocket first, fall back to REST
        if transport == .websocket && sendViaWebSocket(trimmed) {
            return // WebSocket will handle the response
        }

        // REST fallback
        do {
            let _: SendResponse = try await APIClient.shared.post(
                "/api/chat/send",
                body: ["content": trimmed]
            )
        } catch {
            optimisticIds.remove(optimisticId)
            messages.removeAll { $0.id == optimisticId }
            isTyping = false
            self.error = error.localizedDescription
        }
    }

    /// Whether a message is still optimistic (not yet confirmed by server)
    func isOptimistic(_ message: Message) -> Bool {
        optimisticIds.contains(message.id)
    }

    /// Attempt to reconnect WebSocket (called from UI retry)
    func reconnectWebSocket() {
        wsRetryCount = 0
        Task { await connectWebSocket() }
    }

    // MARK: - Private Helpers

    private func mergeMessages(server: [Message]) {
        if optimisticIds.isEmpty {
            messages = server
            return
        }

        let optimistic = messages.filter { optimisticIds.contains($0.id) }
        var matched = Set<String>()

        for opt in optimistic {
            let found = server.contains { msg in
                msg.role == opt.role &&
                msg.content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200) ==
                opt.content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)
            }
            if found { matched.insert(opt.id) }
        }

        for id in matched { optimisticIds.remove(id) }

        if let lastServer = server.last, lastServer.role == "assistant" {
            optimisticIds.removeAll()
            messages = server
            return
        }

        let remaining = optimistic.filter { !matched.contains($0.id) }
        messages = server + remaining
    }

    private func checkTyping() async {
        do {
            let status: ChatStatus = try await APIClient.shared.get("/api/chat/status")
            isTyping = status.typing ?? false
        } catch {
            // Silently ignore typing status errors
        }
    }

    private func stableHash(role: String, content: String) -> String {
        let input = "\(role):\(content.prefix(200))"
        var h: UInt32 = 0
        for c in input.unicodeScalars {
            h = h &* 31 &+ UInt32(c.value)
        }
        return String(h, radix: 36)
    }

    private func getBaseURL() -> String? {
        let url = KeychainHelper.load(key: "server_url") ?? ""
        return url.isEmpty ? nil : url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

// MARK: - WebSocket Message Types

private struct WSMessagesPayload: Codable {
    let messages: [Message]
    let typing: Bool?
}

private struct WSNewMessage: Codable {
    let type: String
    let message: Message?
    let typing: Bool?
}

private struct WSTypingPayload: Codable {
    let typing: Bool
}
