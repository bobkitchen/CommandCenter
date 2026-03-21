import Foundation

struct AlertRecord: Codable, Identifiable {
    let id: String
    let title: String
    let body: String
    let timestamp: Date
    let level: String

    init(title: String, body: String, level: String) {
        self.id = UUID().uuidString
        self.title = title
        self.body = body
        self.timestamp = Date()
        self.level = level
    }
}

@MainActor
final class AlertHistory {
    static let shared = AlertHistory()

    private(set) var alerts: [AlertRecord] = []
    private let maxAlerts = 50

    init() {
        load()
    }

    func add(title: String, body: String, level: String) {
        let record = AlertRecord(title: title, body: body, level: level)
        alerts.insert(record, at: 0)
        if alerts.count > maxAlerts {
            alerts = Array(alerts.prefix(maxAlerts))
        }
        save()
    }

    func clear() {
        alerts = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(alerts) {
            UserDefaults.standard.set(data, forKey: "alertHistory")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "alertHistory"),
           let decoded = try? JSONDecoder().decode([AlertRecord].self, from: data) {
            alerts = decoded
        }
    }
}
