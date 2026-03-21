import SwiftUI

struct CrisesResponse: Codable {
    let crises: [Crisis]
}

struct Crisis: Codable, Identifiable, Hashable {
    let name: String
    let status: String?
    let level: String?
    let updated: String?
    let summary: String?
    let details: String?
    let source: String?
    let createdAt: String?

    var id: String { name }

    func hash(into hasher: inout Hasher) { hasher.combine(name) }
    static func == (lhs: Crisis, rhs: Crisis) -> Bool { lhs.name == rhs.name }

    var levelColor: Color {
        switch level?.lowercased() {
        case "critical", "emergency": return AppColors.danger
        case "serious", "high":       return AppColors.warning
        case "stable", "low":         return AppColors.success
        default:                      return AppColors.muted
        }
    }
}
