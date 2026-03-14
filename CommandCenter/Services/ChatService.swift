import Foundation

@Observable
final class ChatService {
    var messages: [Message] = []
    var isTyping = false
    var error: String?
    private var pollTask: Task<Void, Never>?

    var visibleMessages: [Message] {
        messages.filter { !$0.isHidden }
    }

    func loadHistory() async {
        do {
            let response: MessagesResponse = try await APIClient.shared.get(
                "/api/chat/history",
                queryItems: [URLQueryItem(name: "limit", value: "200")]
            )
            await MainActor.run {
                self.messages = response.messages
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }

    func send(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Optimistic local add
        let tempMessage = Message(
            id: UUID().uuidString,
            role: "user",
            content: trimmed,
            timestamp: "\(Date().timeIntervalSince1970 * 1000)",
            channel: nil
        )
        await MainActor.run {
            self.messages.append(tempMessage)
        }

        do {
            let _: SendResponse = try await APIClient.shared.post(
                "/api/chat/send",
                body: ["content": trimmed]
            )
            // Fetch to get server-side message with real ID
            await loadHistory()
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
            }
        }
    }

    func startPolling() {
        stopPolling()
        pollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { break }
                await loadHistory()
                await checkTyping()
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func checkTyping() async {
        do {
            let status: ChatStatus = try await APIClient.shared.get("/api/chat/status")
            await MainActor.run {
                self.isTyping = status.typing ?? false
            }
        } catch {
            // Silently ignore typing status errors
        }
    }
}
