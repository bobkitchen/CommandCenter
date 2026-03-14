import SwiftUI

struct CrisesResponse: Codable {
    let crises: [Crisis]
}

struct Crisis: Codable, Identifiable {
    let name: String
    let status: String?
    let level: String?
    let updated: String?
    let summary: String?

    var id: String { name }

    var levelColor: Color {
        switch level?.lowercased() {
        case "critical", "emergency": return AppColors.danger
        case "serious", "high":       return AppColors.warning
        case "stable", "low":         return AppColors.success
        default:                      return AppColors.muted
        }
    }
}
