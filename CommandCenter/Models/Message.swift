import Foundation

struct Message: Codable, Identifiable, Equatable {
    let id: String
    let role: String
    let content: String
    let timestamp: String
    let channel: String?

    var isUser: Bool { role == "user" }
    var isSystem: Bool { role == "system" }

    var isHidden: Bool {
        isSystem
        || content.trimmingCharacters(in: .whitespacesAndNewlines) == "HEARTBEAT_OK"
        || content.trimmingCharacters(in: .whitespacesAndNewlines) == "NO_REPLY"
    }

    var cleanedContent: String {
        content
            .replacingOccurrences(of: "[[reply_to_current]]", with: "")
            .replacingOccurrences(of: #"\[\[reply_to_\w+\]\]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var displayTime: String {
        // Try ISO 8601 first, then Unix timestamp
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoFormatterBasic = ISO8601DateFormatter()

        let date: Date?
        if let d = isoFormatter.date(from: timestamp) {
            date = d
        } else if let d = isoFormatterBasic.date(from: timestamp) {
            date = d
        } else if let ts = Double(timestamp) {
            date = Date(timeIntervalSince1970: ts / (ts > 1e12 ? 1000 : 1))
        } else {
            date = nil
        }

        guard let date else { return timestamp }
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: date)
    }

    static func == (lhs: Message, rhs: Message) -> Bool { lhs.id == rhs.id }
}

struct MessagesResponse: Codable {
    let messages: [Message]
}

struct SendResponse: Codable {
    let ok: Bool?
    let error: String?
}

struct ChatStatus: Codable {
    let typing: Bool?
    let status: String?
}
