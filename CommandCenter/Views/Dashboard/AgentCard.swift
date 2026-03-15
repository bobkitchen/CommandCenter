import SwiftUI

// MARK: - API Response Models (matches /api/sessions)

struct SessionEntry: Codable, Identifiable {
    let key: String?
    let kind: String?
    let displayName: String?
    let updatedAt: Double?
    let totalTokens: Int?
    let inputTokens: Int?
    let outputTokens: Int?
    let modelProvider: String?
    let modelId: String?
    let abortedLastRun: Bool?

    var id: String { key ?? UUID().uuidString }

    /// Extract agent name from session key (e.g. "agent:sentinel:main" → "sentinel")
    var agentName: String {
        guard let key else { return displayName ?? "unknown" }
        let parts = key.split(separator: ":")
        if parts.count >= 2 { return String(parts[1]) }
        return displayName ?? key
    }

    var isActive: Bool {
        guard let updatedAt else { return false }
        let age = Date().timeIntervalSince1970 * 1000 - updatedAt
        return age < 600_000 // active if updated in last 10 min
    }

    var statusColor: Color {
        isActive ? AppColors.success : AppColors.muted
    }

    var statusIcon: String {
        isActive ? "circle.fill" : "circle"
    }

    var shortModel: String {
        guard let model = modelId else { return "—" }
        return model
            .replacingOccurrences(of: "anthropic/", with: "")
            .replacingOccurrences(of: "openai/", with: "")
    }

    var relativeTime: String {
        guard let updatedAt else { return "" }
        let seconds = Int((Date().timeIntervalSince1970 * 1000 - updatedAt) / 1000)
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }

    var formattedTokens: String {
        guard let total = totalTokens else { return "—" }
        if total >= 1_000_000 { return String(format: "%.1fM", Double(total) / 1_000_000) }
        if total >= 1_000 { return String(format: "%.0fK", Double(total) / 1_000) }
        return "\(total)"
    }
}

struct SessionsResponse: Codable {
    let sessions: [SessionEntry]?
}

// MARK: - AgentCard View

struct AgentCard: View {
    @State private var sessions: [SessionEntry] = []
    @State private var isLoading = true
    @State private var loadError = false

    private var activeSessions: [SessionEntry] {
        sessions.filter { $0.isActive }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Agents", systemImage: "cpu")
                    .font(.headline)
                    .foregroundStyle(AppColors.accent)

                Spacer()

                HStack(spacing: 8) {
                    if !activeSessions.isEmpty {
                        HStack(spacing: 3) {
                            Circle()
                                .fill(AppColors.success)
                                .frame(width: 5, height: 5)
                            Text("\(activeSessions.count) active")
                                .font(.caption2)
                                .foregroundStyle(AppColors.success)
                        }
                    }
                    Text("\(sessions.count) total")
                        .font(.caption)
                        .foregroundStyle(AppColors.muted)
                }
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
                    ForEach(sessions.prefix(6)) { session in
                        HStack(spacing: 10) {
                            Image(systemName: session.statusIcon)
                                .foregroundStyle(session.statusColor)
                                .font(.caption)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(session.agentName)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppColors.text)
                                    .lineLimit(1)

                                HStack(spacing: 6) {
                                    Text(session.shortModel)
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.muted)

                                    Text("·")
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.muted)

                                    Text(session.formattedTokens)
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.muted)
                                }
                            }

                            Spacer()

                            Text(session.relativeTime)
                                .font(.caption2)
                                .foregroundStyle(AppColors.muted)
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
            let response: SessionsResponse = try await APIClient.shared.get(
                "/api/sessions",
                queryItems: [URLQueryItem(name: "limit", value: "10")]
            )
            // Sort by most recently active
            sessions = (response.sessions ?? []).sorted {
                ($0.updatedAt ?? 0) > ($1.updatedAt ?? 0)
            }
        } catch {
            loadError = true
        }
        isLoading = false
    }
}
