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
    private var connectTask: Task<Void, Never>?
    private var optimisticIds: Set<String> = []
    private var webSocketTask: URLSessionWebSocketTask?
    private var wsSession: URLSession?
    private var wsRetryCount = 0
    private let maxWsRetries = 5
    private var lastSendTime: Date?
    private var wsConfirmed = false  // True only after first successful receive
    private var isStopped = false

    var visibleMessages: [Message] {
        messages.filter { !$0.isHidden }
    }

    // MARK: - Lifecycle

    func start() async {
        isStopped = false
        wsRetryCount = 0
        await loadHistory()
        startPolling()
        connectWebSocketInBackground()
    }

    func stop() {
        isStopped = true
        stopPolling()
        cancelConnectTask()
        disconnectWebSocket()
    }

    /// Call when app returns to foreground or connectivity is restored
    func resume() {
        guard !isStopped else { return }
        // Always ensure polling is running
        startPolling()
        // If WebSocket isn't confirmed, try to reconnect
        if !wsConfirmed {
            wsRetryCount = 0
            connectWebSocketInBackground()
        } else if let ws = webSocketTask, ws.state != .running {
            // WebSocket died while backgrounded
            wsConfirmed = false
            wsRetryCount = 0
            connectWebSocketInBackground()
        }
        // Immediately refresh history
        Task { await loadHistory() }
    }

    // MARK: - WebSocket

    private func connectWebSocketInBackground() {
        cancelConnectTask()
        connectTask = Task { [weak self] in
            await self?.connectWebSocket()
        }
    }

    private func cancelConnectTask() {
        connectTask?.cancel()
        connectTask = nil
    }

    private func connectWebSocket() async {
        guard !isStopped else { return }
        guard let baseURL = getBaseURL() else {
            transport = .polling
            return
        }

        let wsURL = baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")

        guard let url = URL(string: "\(wsURL)/api/chat/ws") else {
            transport = .polling
            return
        }

        print("[Chat] Connecting WebSocket to \(url.absoluteString)")
        transport = .connecting

        // Clean up old connection
        disconnectWebSocket()

        // Build request with cookies
        var request = URLRequest(url: url)
        if let cookies = HTTPCookieStorage.shared.cookies(for: URL(string: baseURL)!) {
            let headers = HTTPCookie.requestHeaderFields(with: cookies)
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        // Create fresh session — use finishTasksAndInvalidate on old one
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpShouldSetCookies = true
        let session = URLSession(configuration: config)
        wsSession = session

        let ws = session.webSocketTask(with: request)
        webSocketTask = ws
        wsConfirmed = false
        ws.resume()

        // Start listen loop — WebSocket is "confirmed" on first successful receive
        wsTask = Task { [weak self] in
            await self?.wsListenLoop(ws)
        }
    }

    private func wsListenLoop(_ ws: URLSessionWebSocketTask) async {
        while !Task.isCancelled && ws.state == .running {
            do {
                let message = try await ws.receive()
                // First successful receive confirms the WebSocket is truly working
                if !wsConfirmed {
                    wsConfirmed = true
                    wsRetryCount = 0
                    transport = .websocket
                    print("[Chat] WebSocket confirmed after first message")
                }
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
                if Task.isCancelled { return }
                print("[Chat] WebSocket receive error: \(error.localizedDescription)")
                break
            }
        }

        // Connection dropped — try to reconnect
        if !Task.isCancelled && !isStopped {
            await handleWebSocketDisconnect()
        }
    }

    private func handleWebSocketMessage(_ text: String) async {
        guard let data = text.data(using: .utf8) else { return }

        // Type 1: A single new message or typing indicator
        if let msg = try? JSONDecoder().decode(WSNewMessage.self, from: data) {
            if msg.type == "message", let message = msg.message {
                if messages.contains(where: { $0.id == message.id }) {
                    return
                }
                if let optIdx = messages.firstIndex(where: {
                    optimisticIds.contains($0.id) &&
                    $0.role == message.role &&
                    $0.content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200) ==
                    message.content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)
                }) {
                    optimisticIds.remove(messages[optIdx].id)
                    messages[optIdx] = message
                } else {
                    messages.append(message)
                }
                if message.role == "assistant" {
                    isTyping = false
                }
            } else if msg.type == "typing" {
                isTyping = msg.typing ?? false
            } else if msg.type == "connected" {
                print("[Chat] WS connected confirmation from server")
            }
            return
        }

        // Type 2: A full messages array update
        if let response = try? JSONDecoder().decode(WSMessagesPayload.self, from: data) {
            mergeMessages(server: response.messages)
            if let typing = response.typing {
                isTyping = typing
            }
            return
        }

        // Type 3: Simple typing indicator
        if let status = try? JSONDecoder().decode(WSTypingPayload.self, from: data) {
            isTyping = status.typing
            return
        }
    }

    private func handleWebSocketDisconnect() async {
        wsConfirmed = false
        disconnectWebSocket()
        wsRetryCount += 1

        // Polling is always running as safety net, just make sure transport reflects reality
        if transport != .polling {
            transport = .polling
        }
        startPolling()

        guard !isStopped else { return }

        if wsRetryCount <= maxWsRetries {
            let delay = min(UInt64(pow(2.0, Double(wsRetryCount - 1))), 30)
            print("[Chat] WebSocket reconnecting in \(delay)s (attempt \(wsRetryCount)/\(maxWsRetries))")
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled && !isStopped else { return }
            await connectWebSocket()
        } else {
            print("[Chat] WebSocket failed after \(maxWsRetries) attempts, staying on polling")
            // Schedule a background retry in 60s — don't give up forever
            try? await Task.sleep(for: .seconds(60))
            guard !Task.isCancelled && !isStopped else { return }
            wsRetryCount = 0
            print("[Chat] Retrying WebSocket after cooldown")
            await connectWebSocket()
        }
    }

    private func disconnectWebSocket() {
        wsTask?.cancel()
        wsTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        // Properly invalidate old session to prevent leaks
        wsSession?.finishTasksAndInvalidate()
        wsSession = nil
    }

    /// Attempt to reconnect WebSocket (called from UI retry)
    func reconnectWebSocket() {
        wsConfirmed = false
        wsRetryCount = 0
        disconnectWebSocket()
        cancelConnectTask()
        connectWebSocketInBackground()
    }

    // MARK: - Polling (always-on safety net)

    func startPolling() {
        guard pollTask == nil else { return }
        if transport != .websocket {
            transport = .polling
        }
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

    /// Adaptive polling: faster when waiting for a reply, slower when WebSocket is active
    private var adaptivePollInterval: Double {
        // If WebSocket is confirmed working, poll infrequently as backup
        if wsConfirmed {
            return 15.0
        }
        // If user sent a message in the last 30s, poll fast
        if let lastSend = lastSendTime,
           Date().timeIntervalSince(lastSend) < 30 {
            return 1.0
        }
        if isTyping {
            return 1.0
        }
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
            // Clear error on successful load
            if error != nil { error = nil }
        } catch let apiError as APIError where apiError == .unauthorized {
            print("[Chat] History load returned 401 — session expired")
            self.error = "Session expired — please sign in again"
            // Stop polling to avoid hammering server with 401s
            stopPolling()
        } catch {
            print("[Chat] History load failed: \(error.localizedDescription)")
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

        // Always send via REST
        do {
            let _: SendResponse = try await APIClient.shared.post(
                "/api/chat/send",
                body: ["content": trimmed]
            )
        } catch {
            print("[Chat] REST send failed: \(error.localizedDescription)")
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

        // If the server has an assistant reply, all pending user messages must have been received
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

// Make APIError equatable for pattern matching
extension APIError: Equatable {
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL): return true
        case (.invalidResponse, .invalidResponse): return true
        case (.unauthorized, .unauthorized): return true
        case (.httpError(let a), .httpError(let b)): return a == b
        default: return false
        }
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
