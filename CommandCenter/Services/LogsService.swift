import Foundation

@MainActor @Observable
final class LogsService {
    var lines: [LogLine] = []
    var isConnected = false
    var isLoading = false
    var error: String?
    var source: LogSource = .all

    private var wsTask: Task<Void, Never>?
    private var webSocketTask: URLSessionWebSocketTask?

    // MARK: - Types

    enum LogSource: String, CaseIterable {
        case all, gateway, server
    }

    struct LogLine: Identifiable, Equatable {
        let id = UUID()
        let timestamp: String
        let level: String
        let source: String
        let message: String

        var levelColor: String {
            switch level.lowercased() {
            case "error": return "danger"
            case "warn", "warning": return "warning"
            case "info": return "accent"
            default: return "muted"
            }
        }
    }

    // MARK: - REST

    func loadInitialLogs() async {
        isLoading = true
        error = nil
        do {
            let response: LogsResponse = try await APIClient.shared.get(
                "/api/logs",
                queryItems: [
                    URLQueryItem(name: "lines", value: "200"),
                    URLQueryItem(name: "source", value: source.rawValue)
                ]
            )
            lines = response.lines.map { entry in
                LogLine(
                    timestamp: entry.timestamp ?? "",
                    level: entry.level ?? "info",
                    source: entry.source ?? source.rawValue,
                    message: entry.message ?? entry.line ?? ""
                )
            }
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - WebSocket

    func connectWebSocket() {
        guard let baseURL = getBaseURL() else { return }

        let wsBase = baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")

        guard let url = URL(string: "\(wsBase)/api/logs/ws?source=\(source.rawValue)") else { return }

        disconnect()

        let config = URLSessionConfiguration.default
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpShouldSetCookies = true
        let session = URLSession(configuration: config)

        let ws = session.webSocketTask(with: url)
        webSocketTask = ws
        ws.resume()

        wsTask = Task { [weak self] in
            guard let self else { return }

            try? await Task.sleep(for: .milliseconds(500))

            do {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                    ws.sendPing { err in
                        if let err { cont.resume(throwing: err) } else { cont.resume() }
                    }
                }
                await MainActor.run { self.isConnected = true }
                print("[Logs] WebSocket connected (\(self.source.rawValue))")
                await self.wsListenLoop(ws)
            } catch {
                print("[Logs] WebSocket ping failed: \(error.localizedDescription)")
                await MainActor.run { self.isConnected = false }
            }
        }
    }

    func disconnect() {
        wsTask?.cancel()
        wsTask = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    func clearLogs() {
        lines.removeAll()
    }

    // MARK: - Private

    private func wsListenLoop(_ ws: URLSessionWebSocketTask) async {
        while !Task.isCancelled && ws.state == .running {
            do {
                let message = try await ws.receive()
                switch message {
                case .string(let text):
                    await handleWSMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        await handleWSMessage(text)
                    }
                @unknown default:
                    break
                }
            } catch {
                print("[Logs] WebSocket receive error: \(error.localizedDescription)")
                break
            }
        }

        if !Task.isCancelled {
            await MainActor.run { self.isConnected = false }
        }
    }

    private func handleWSMessage(_ text: String) async {
        guard let data = text.data(using: .utf8),
              let payload = try? JSONDecoder().decode(WSLogEvent.self, from: data)
        else { return }

        // Ignore keepalive pings
        guard payload.type == "log" else { return }

        let newLine = LogLine(
            timestamp: payload.timestamp ?? "",
            level: payload.level ?? "info",
            source: payload.source ?? source.rawValue,
            message: payload.line ?? ""
        )

        lines.append(newLine)

        // Cap at 1000 lines
        if lines.count > 1000 {
            lines.removeFirst(lines.count - 1000)
        }
    }

    private func getBaseURL() -> String? {
        let url = KeychainHelper.load(key: "server_url") ?? ""
        return url.isEmpty ? nil : url.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

// MARK: - Codable Models

struct LogsResponse: Codable {
    let lines: [LogEntry]

    struct LogEntry: Codable {
        let timestamp: String?
        let level: String?
        let source: String?
        let message: String?
        let line: String?
    }
}

private struct WSLogEvent: Codable {
    let type: String
    let line: String?
    let source: String?
    let level: String?
    let timestamp: String?
}
