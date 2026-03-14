import Foundation

struct CalendarResponse: Codable {
    let events: [CalendarEvent]
}

struct CalendarEvent: Codable, Identifiable {
    let title: String
    let start: String
    let end: String?
    let location: String?
    let calendar: String?

    var id: String { "\(title)-\(start)" }

    var startTime: String {
        parseTime(from: start) ?? start
    }

    var endTime: String? {
        guard let end else { return nil }
        return parseTime(from: end)
    }

    private func parseTime(from str: String) -> String? {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()

        let date: Date?
        if let d = isoFormatter.date(from: str) {
            date = d
        } else if let d = isoBasic.date(from: str) {
            date = d
        } else {
            date = nil
        }
        guard let date else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt.string(from: date)
    }
}
