import SwiftUI
#if os(iOS)
import AuthenticationServices
#endif

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

    var relativeDate: String {
        guard let start_date else { return "" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        // Try with fractional seconds first, then without
        if let date = formatter.date(from: start_date) {
            return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
        }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: start_date) {
            return RelativeDateTimeFormatter().localizedString(for: date, relativeTo: Date())
        }
        return ""
    }
}

struct StravaCard: View {
    @State private var strava = StravaService.shared
    #if os(iOS)
    @State private var showSetup = false
    #endif

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Strava", systemImage: "figure.run")
                    .font(.headline)
                    .foregroundStyle(.orange)

                Spacer()

                if strava.isConnected {
                    Button {
                        Task { await strava.fetchData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundStyle(AppColors.muted)
                    }
                    .buttonStyle(.plain)
                }
            }

            if !strava.isConnected {
                connectPrompt
            } else if strava.isLoading && strava.activities.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if let error = strava.error {
                ErrorRetryView(message: error) {
                    Task { await strava.fetchData() }
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                activitiesSection
                statsSection
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .task {
            if strava.isConnected {
                await strava.fetchData()
            }
        }
        #if os(iOS)
        .sheet(isPresented: $showSetup) {
            StravaSetupSheet(strava: strava)
        }
        #endif
    }

    private var connectPrompt: some View {
        VStack(spacing: 8) {
            Text("Connect your Strava account to see activities")
                .font(.caption)
                .foregroundStyle(AppColors.muted)
                .multilineTextAlignment(.center)

            #if os(iOS)
            Button("Connect Strava") {
                showSetup = true
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.orange, in: RoundedRectangle(cornerRadius: 8))
            #else
            Text("Set up Strava in Settings")
                .font(.caption)
                .foregroundStyle(AppColors.muted)
            #endif
        }
        .frame(maxWidth: .infinity, minHeight: 60)
    }

    @ViewBuilder
    private var activitiesSection: some View {
        if !strava.activities.isEmpty {
            VStack(spacing: 8) {
                ForEach(strava.activities.prefix(3)) { activity in
                    HStack {
                        Image(systemName: activityIcon(activity.type))
                            .foregroundStyle(.orange)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(activity.name ?? "Activity")
                                .font(.subheadline)
                                .foregroundStyle(AppColors.text)
                                .lineLimit(1)
                            Text(activity.relativeDate)
                                .font(.caption2)
                                .foregroundStyle(AppColors.muted)
                        }

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
    }

    @ViewBuilder
    private var statsSection: some View {
        if let ytdRun = strava.stats?.ytd_run_totals,
           let ytdRide = strava.stats?.ytd_ride_totals {
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
}

// MARK: - Strava Setup Sheet (iOS)

#if os(iOS)
struct StravaSetupSheet: View {
    let strava: StravaService
    @Environment(\.dismiss) private var dismiss
    @State private var clientId: String = ""
    @State private var clientSecret: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Create a Strava API app at strava.com/settings/api, then enter your credentials below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Strava API Credentials") {
                    TextField("Client ID", text: $clientId)
                        .keyboardType(.numberPad)
                    SecureField("Client Secret", text: $clientSecret)
                }

                Section {
                    Button("Connect to Strava") {
                        strava.clientId = clientId
                        strava.clientSecret = clientSecret

                        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = scene.windows.first {
                            Task {
                                await strava.authenticate(from: window)
                                if strava.isConnected {
                                    dismiss()
                                }
                            }
                        }
                    }
                    .disabled(clientId.isEmpty || clientSecret.isEmpty)
                }
            }
            .navigationTitle("Connect Strava")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .onAppear {
            clientId = strava.clientId
            clientSecret = strava.clientSecret
        }
    }
}
#endif
