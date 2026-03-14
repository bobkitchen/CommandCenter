import SwiftUI

struct StravaStats: Codable {
    let recent_ride_totals: ActivityTotals?
    let ytd_ride_totals: ActivityTotals?
    let recent_run_totals: ActivityTotals?
    let ytd_run_totals: ActivityTotals?
}

struct ActivityTotals: Codable {
    let count: Int?
    let distance: Double?
    let moving_time: Int?
    let elevation_gain: Double?
}

struct StravaActivity: Codable, Identifiable {
    let id: Int?
    let name: String?
    let type: String?
    let distance: Double?
    let moving_time: Int?
    let start_date: String?

    var displayDistance: String {
        guard let d = distance else { return "—" }
        return String(format: "%.1f km", d / 1000)
    }

    var displayTime: String {
        guard let t = moving_time else { return "—" }
        let h = t / 3600
        let m = (t % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
}

struct StravaResponse: Codable {
    let stats: StravaStats?
    let activities: [StravaActivity]?
}

struct StravaCard: View {
    @State private var data: StravaResponse?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Strava", systemImage: "figure.run")
                .font(.headline)
                .foregroundStyle(.orange)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if let data {
                // Recent activities
                if let activities = data.activities, !activities.isEmpty {
                    VStack(spacing: 8) {
                        ForEach(activities.prefix(3)) { activity in
                            HStack {
                                Image(systemName: activityIcon(activity.type))
                                    .foregroundStyle(.orange)
                                    .frame(width: 20)

                                Text(activity.name ?? "Activity")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.text)
                                    .lineLimit(1)

                                Spacer()

                                Text(activity.displayDistance)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.muted)

                                Text(activity.displayTime)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.muted)
                                    .frame(width: 50, alignment: .trailing)
                            }
                        }
                    }
                }

                // YTD summary
                if let ytdRun = data.stats?.ytd_run_totals, let ytdRide = data.stats?.ytd_ride_totals {
                    Divider().overlay(AppColors.border)
                    HStack(spacing: 16) {
                        statBadge(
                            icon: "figure.run",
                            value: "\(Int((ytdRun.distance ?? 0) / 1000)) km",
                            label: "YTD Run"
                        )
                        statBadge(
                            icon: "bicycle",
                            value: "\(Int((ytdRide.distance ?? 0) / 1000)) km",
                            label: "YTD Ride"
                        )
                    }
                }
            } else {
                Text("Unable to load Strava data")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .task { await loadStrava() }
    }

    private func statBadge(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.text)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(AppColors.muted)
            }
        }
    }

    private func activityIcon(_ type: String?) -> String {
        switch type?.lowercased() {
        case "run": return "figure.run"
        case "ride": return "bicycle"
        case "swim": return "figure.pool.swim"
        case "walk", "hike": return "figure.walk"
        default: return "flame"
        }
    }

    private func loadStrava() async {
        do {
            data = try await APIClient.shared.get("/api/strava")
        } catch {}
        isLoading = false
    }
}
