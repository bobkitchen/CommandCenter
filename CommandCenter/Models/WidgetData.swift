import Foundation

/// Shared data structure between the main app and the widget extension.
/// Written by OpenClawMonitor, read by the widget.
struct WidgetData: Codable {
    let isConnected: Bool
    let contextPercent: Double
    let healthSummary: String
    let model: String
    let uptime: String
    let agentCount: Int
    let lastUpdated: Date
    let processNames: [String]
    let processStatuses: [String]
    let cronActive: Int
    let cronTotal: Int

    static let placeholder = WidgetData(
        isConnected: true,
        contextPercent: 42,
        healthSummary: "All Systems Operational",
        model: "sonnet-4",
        uptime: "2d 5h",
        agentCount: 3,
        lastUpdated: Date(),
        processNames: ["gateway", "server"],
        processStatuses: ["online", "online"],
        cronActive: 3,
        cronTotal: 5
    )

    static func load() -> WidgetData {
        guard let defaults = UserDefaults(suiteName: "group.com.bobkitchen.commandcenter"),
              let data = defaults.data(forKey: "widgetData"),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .placeholder
        }
        return decoded
    }

    func save() {
        guard let defaults = UserDefaults(suiteName: "group.com.bobkitchen.commandcenter"),
              let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: "widgetData")
    }
}
