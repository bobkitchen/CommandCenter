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

    static let defaultOrder: [DashboardCard] = [
        .status, .tokenUsage, .quickActions, .activityFeed,
        .crises, .memory, .calendar, .weather, .strava
    ]
}

@MainActor @Observable
final class DashboardConfig {
    static let shared = DashboardConfig()

    // Stored properties so @Observable can track changes
    var cardOrder: [DashboardCard]
    var hiddenCards: Set<DashboardCard>

    var visibleCards: [DashboardCard] {
        cardOrder.filter { !hiddenCards.contains($0) }
    }

    init() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "dashboardCardOrder"),
           let decoded = try? JSONDecoder().decode([DashboardCard].self, from: data) {
            let missing = DashboardCard.defaultOrder.filter { !decoded.contains($0) }
            self.cardOrder = decoded + missing
        } else {
            self.cardOrder = DashboardCard.defaultOrder
        }

        if let data = UserDefaults.standard.data(forKey: "dashboardHiddenCards"),
           let decoded = try? JSONDecoder().decode(Set<DashboardCard>.self, from: data) {
            self.hiddenCards = decoded
        } else {
            self.hiddenCards = []
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(cardOrder) {
            UserDefaults.standard.set(data, forKey: "dashboardCardOrder")
        }
        if let data = try? JSONEncoder().encode(hiddenCards) {
            UserDefaults.standard.set(data, forKey: "dashboardHiddenCards")
        }
    }

    func moveCard(from source: IndexSet, to destination: Int) {
        var order = cardOrder
        order.move(fromOffsets: source, toOffset: destination)
        cardOrder = order
        save()
    }

    func toggleCard(_ card: DashboardCard) {
        if hiddenCards.contains(card) {
            hiddenCards.remove(card)
        } else {
            hiddenCards.insert(card)
        }
        save()
    }

    func resetToDefaults() {
        cardOrder = DashboardCard.defaultOrder
        hiddenCards = []
        save()
    }
}
