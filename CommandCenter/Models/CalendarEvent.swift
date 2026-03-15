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
        DateFormatters.formatTime(from: start)
    }

    var endTime: String? {
        guard let end else { return nil }
        return DateFormatters.formatTime(from: end)
    }
}
