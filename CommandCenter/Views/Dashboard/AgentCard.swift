import SwiftUI

struct AgentSession: Codable, Identifiable {
    let id: String?
    let name: String?
    let status: String?
    let model: String?
    let channel: String?
    let created: String?

    var stableID: String { id ?? (name ?? UUID().uuidString) }

    var statusColor: Color {
        switch status?.lowercased() {
        case "running", "active": return AppColors.success
        case "idle", "waiting":   return AppColors.warning
        case "error", "failed":   return AppColors.danger
        default:                  return AppColors.muted
        }
    }

    var statusIcon: String {
        switch status?.lowercased() {
        case "running", "active": return "circle.fill"
        case "idle", "waiting":   return "pause.circle.fill"
        case "error", "failed":   return "xmark.circle.fill"
        default:                  return "circle"
        }
    }
}

struct AgentSessionsResponse: Codable {
    let sessions: [AgentSession]?
}

struct AgentCard: View {
    @State private var sessions: [AgentSession] = []
    @State private var isLoading = true
    @State private var loadError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Agents", systemImage: "cpu")
                    .font(.headline)
                    .foregroundStyle(AppColors.accent)

                Spacer()

                Text("\(sessions.count) sessions")
                    .font(.caption)
                    .foregroundStyle(AppColors.muted)
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if loadError {
                ErrorRetryView(message: "Unable to load sessions") {
                    Task { await loadSessions() }
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else if sessions.isEmpty {
                Text("No active sessions")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.muted)
            } else {
                VStack(spacing: 8) {
                    ForEach(sessions.prefix(5), id: \.stableID) { session in
                        HStack(spacing: 10) {
                            Image(systemName: session.statusIcon)
                                .foregroundStyle(session.statusColor)
                                .font(.caption)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.name ?? session.stableID)
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.text)
                                    .lineLimit(1)

                                HStack(spacing: 6) {
                                    if let model = session.model {
                                        Text(model)
                                            .font(.caption2)
                                            .foregroundStyle(AppColors.muted)
                                    }
                                    if let channel = session.channel {
                                        Text("· \(channel)")
                                            .font(.caption2)
                                            .foregroundStyle(AppColors.muted)
                                    }
                                }
                            }

                            Spacer()

                            if let status = session.status {
                                Text(status)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(session.statusColor)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .task { await loadSessions() }
    }

    private func loadSessions() async {
        isLoading = true
        loadError = false
        do {
            let response: AgentSessionsResponse = try await APIClient.shared.get(
                "/api/sessions",
                queryItems: [URLQueryItem(name: "limit", value: "10")]
            )
            sessions = response.sessions ?? []
        } catch {
            loadError = true
        }
        isLoading = false
    }
}
