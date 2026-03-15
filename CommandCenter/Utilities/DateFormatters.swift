import Foundation

enum DateFormatters {
    nonisolated(unsafe) static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    nonisolated(unsafe) static let isoBasic = ISO8601DateFormatter()

    nonisolated(unsafe) static let timeOnly: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    nonisolated(unsafe) static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    static func parseDate(from string: String) -> Date? {
        if let d = isoFractional.date(from: string) { return d }
        if let d = isoBasic.date(from: string) { return d }
        if let ts = Double(string) {
            return Date(timeIntervalSince1970: ts / (ts > 1e12 ? 1000 : 1))
        }
        return nil
    }

    static func formatTime(from string: String) -> String {
        guard let date = parseDate(from: string) else { return string }
        return timeOnly.string(from: date)
    }

    static func formatRelative(from string: String) -> String {
        guard let date = parseDate(from: string) else { return string }
        return relative.localizedString(for: date, relativeTo: Date())
    }
}
