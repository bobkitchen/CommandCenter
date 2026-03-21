import Foundation

struct NotificationSettings: Codable {
    var gatewayAlerts: Bool = true
    var contextAlerts: Bool = true
    var processAlerts: Bool = true
    var cronAlerts: Bool = true
    var contextThreshold: Double = 85

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: "notificationSettings")
        }
    }

    static func load() -> NotificationSettings {
        guard let data = UserDefaults.standard.data(forKey: "notificationSettings"),
              let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) else {
            return NotificationSettings()
        }
        return settings
    }
}
