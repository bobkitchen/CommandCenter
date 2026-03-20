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
        DateFormatters.formatTime(from: timestamp)
    }

    var dateHeader: String? {
        DateFormatters.formatDateHeader(from: timestamp)
    }

    var parsedDate: Date? {
        DateFormatters.parseDate(from: timestamp)
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
