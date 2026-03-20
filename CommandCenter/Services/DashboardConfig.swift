import Foundation

enum DashboardCard: String, CaseIterable, Codable, Identifiable {
    case status = "OpenClaw Status"
    case tokenUsage = "Token Usage"
    case activityFeed = "Activity Feed"
    case quickActions = "Quick Actions"
    case crises = "Crises"
    case memory = "Memory"
    case calendar = "Calendar"
    case weather = "Weather"
    case strava = "Strava"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .status: return "server.rack"
        case .tokenUsage: return "chart.bar"
        case .activityFeed: return "list.bullet.rectangle"
        case .quickActions: return "bolt.fill"
        case .crises: return "exclamationmark.triangle.fill"
        case .memory: return "brain"
        case .calendar: return "calendar"
        case .weather: return "cloud.sun.fill"
        case .strava: return "figure.run"
        }
    }

    /// Default order optimized for monitoring
    static let defaultOrder: [DashboardCard] = [
        .status, .tokenUsage, .quickActions, .activityFeed,
        .crises, .memory, .calendar, .weather, .strava
    ]
}

@MainActor @Observable
final class DashboardConfig {
    static let shared = DashboardConfig()

    var cardOrder: [DashboardCard] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "dashboardCardOrder"),
                  let decoded = try? JSONDecoder().decode([DashboardCard].self, from: data) else {
                return DashboardCard.defaultOrder
            }
            // Add any new cards not yet in saved order
            let missing = DashboardCard.defaultOrder.filter { !decoded.contains($0) }
            return decoded + missing
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "dashboardCardOrder")
            }
        }
    }

    var hiddenCards: Set<DashboardCard> {
        get {
            guard let data = UserDefaults.standard.data(forKey: "dashboardHiddenCards"),
                  let decoded = try? JSONDecoder().decode(Set<DashboardCard>.self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "dashboardHiddenCards")
            }
        }
    }

    var visibleCards: [DashboardCard] {
        cardOrder.filter { !hiddenCards.contains($0) }
    }

    func moveCard(from source: IndexSet, to destination: Int) {
        var order = cardOrder
        order.move(fromOffsets: source, toOffset: destination)
        cardOrder = order
    }

    func toggleCard(_ card: DashboardCard) {
        var hidden = hiddenCards
        if hidden.contains(card) {
            hidden.remove(card)
        } else {
            hidden.insert(card)
        }
        hiddenCards = hidden
    }

    func resetToDefaults() {
        cardOrder = DashboardCard.defaultOrder
        hiddenCards = []
    }
}
