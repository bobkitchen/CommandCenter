import Foundation

@MainActor @Observable
final class ChatService {
    var messages: [Message] = []
    var isTyping = false
    var error: String?
    private var pollTask: Task<Void, Never>?
    private var optimisticIds: Set<String> = []

    var visibleMessages: [Message] {
        messages.filter { !$0.isHidden }
    }

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

        // Optimistic local add — use content-based ID for stable matching
        let optimisticId = "opt-\(stableHash(role: "user", content: trimmed))"
        let tempMessage = Message(
            id: optimisticId,
            role: "user",
            content: trimmed,
            timestamp: ISO8601DateFormatter().string(from: Date()),
            channel: "web"
        )
        optimisticIds.insert(optimisticId)
        messages.append(tempMessage)
        isTyping = true

        do {
            let _: SendResponse = try await APIClient.shared.post(
                "/api/chat/send",
                body: ["content": trimmed]
            )
            // History will be refreshed by polling — SSE not available in native app
        } catch {
            // Remove optimistic message on failure
            optimisticIds.remove(optimisticId)
            messages.removeAll { $0.id == optimisticId }
            isTyping = false
            self.error = error.localizedDescription
        }
    }

    func startPolling() {
        stopPolling()
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
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

    /// Whether a message is still optimistic (not yet confirmed by server)
    func isOptimistic(_ message: Message) -> Bool {
        optimisticIds.contains(message.id)
    }

    // MARK: - Private

    /// Merge server messages with optimistic ones, matching by content to avoid flash
    private func mergeMessages(server: [Message]) {
        if optimisticIds.isEmpty {
            messages = server
            return
        }

        let optimistic = messages.filter { optimisticIds.contains($0.id) }
        var matched = Set<String>()

        // Check if server now contains our optimistic messages (by content match)
        for opt in optimistic {
            let found = server.contains { msg in
                msg.role == opt.role &&
                msg.content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200) ==
                opt.content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200)
            }
            if found {
                matched.insert(opt.id)
            }
        }

        // Clear matched optimistic IDs
        for id in matched {
            optimisticIds.remove(id)
        }

        // If an assistant reply appeared, all optimistic messages were received
        if let lastServer = server.last, lastServer.role == "assistant" {
            optimisticIds.removeAll()
            messages = server
            return
        }

        // Append any remaining unmatched optimistic messages
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

    /// Simple content hash for matching optimistic to server messages
    private func stableHash(role: String, content: String) -> String {
        let input = "\(role):\(content.prefix(200))"
        var h: UInt32 = 0
        for c in input.unicodeScalars {
            h = h &* 31 &+ UInt32(c.value)
        }
        return String(h, radix: 36)
    }
}
