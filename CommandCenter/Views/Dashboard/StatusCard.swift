import SwiftUI

// MARK: - API Response Models (matches /api/openclaw-status)

struct OpenClawStatusResponse: Codable {
    let timestamp: Double?
    let fetchTime: Double?
    let gateway: GatewayStatus?
    let model: ModelInfo?
    let mainSession: MainSessionInfo?
    let sessions: SessionsSummary?
    let agents: [AgentSummary]?
    let heartbeat: HeartbeatInfo?
    let cron: CronInfo?
    let pm2: PM2Info?
}

struct GatewayStatus: Codable {
    let connected: Bool?
    let latency: Double?
    let uptime: Double? // milliseconds
    let pid: Int?
    let memory: Double?
    let cpu: Double?
    let restarts: Int?
}

struct ModelInfo: Codable {
    let `default`: String?
    let contextWindow: Int?
}

struct MainSessionInfo: Codable {
    let percentUsed: Double?
    let totalTokens: Int?
    let remainingTokens: Int?
    let contextTokens: Int?
    let inputTokens: Int?
    let outputTokens: Int?
    let cacheRead: Int?
    let cacheWrite: Int?
    let model: String?
    let lastActivity: String?
}

struct SessionsSummary: Codable {
    let total: Int?
    let details: [SessionDetail]?
}

struct SessionDetail: Codable {
    let key: String?
    let agent: String?
    let model: String?
    let percentUsed: Double?
    let totalTokens: Int?
    let remainingTokens: Int?
    let lastActivity: String?
}

struct AgentSummary: Codable {
    let agentId: String?
    let sessionCount: Int?
    let mostRecent: String?
}

struct HeartbeatInfo: Codable {
    let active: [HeartbeatAgent]?
    let total: Int?
}

struct HeartbeatAgent: Codable {
    let agentId: String?
    let every: Int?
}

struct CronInfo: Codable {
    let total: Int?
    let enabled: Int?
}

struct PM2Info: Codable {
    let processes: [PM2Process]?
    let commandCenter: PM2ProcessStatus?
}

struct PM2Process: Codable {
    let name: String?
    let pid: Int?
    let status: String?
    let uptime: Double?
    let memory: Double?
    let cpu: Double?
    let restarts: Int?
}

struct PM2ProcessStatus: Codable {
    let status: String?
    let uptime: Double?
    let memory: Double?
    let restarts: Int?
}

// MARK: - StatusCard View

struct StatusCard: View {
    @State private var status: OpenClawStatusResponse?
    @State private var isLoading = true
    @State private var loadError = false

    private var isConnected: Bool {
        status?.gateway?.connected ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("OpenClaw", systemImage: "server.rack")
                    .font(.headline)
                    .foregroundStyle(isConnected ? AppColors.success : AppColors.danger)

                Spacer()

                if isConnected {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.success)
                            .frame(width: 6, height: 6)
                        Text("Connected")
                            .font(.caption2)
                            .foregroundStyle(AppColors.success)
                    }
                }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if loadError {
                ErrorRetryView(message: "Unable to connect") {
                    Task { await loadStatus() }
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else if let status {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    statusItem(label: "Model", value: shortenModel(status.model?.default))
                    statusItem(label: "Uptime", value: formatUptime(status.gateway?.uptime))
                    statusItem(label: "Sessions", value: "\(status.sessions?.total ?? 0)")
                    statusItem(label: "Latency", value: formatLatency(status.gateway?.latency))

                    if let main = status.mainSession {
                        statusItem(label: "Context", value: formatPercent(main.percentUsed))
                        statusItem(label: "Tokens", value: formatTokens(main.totalTokens))
                    }

                    if let cron = status.cron {
                        statusItem(label: "Cron Jobs", value: "\(cron.enabled ?? 0)/\(cron.total ?? 0)")
                    }

                    statusItem(label: "Restarts", value: "\(status.gateway?.restarts ?? 0)")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: isConnected ? AppColors.success.opacity(0.08) : nil)
        .task { await loadStatus() }
    }

    private func statusItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColors.muted)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Formatters

    private func shortenModel(_ model: String?) -> String {
        guard let model else { return "—" }
        return model
            .replacingOccurrences(of: "anthropic/", with: "")
            .replacingOccurrences(of: "openai/", with: "")
    }

    private func formatUptime(_ ms: Double?) -> String {
        guard let ms, ms > 0 else { return "—" }
        let seconds = Int(ms / 1000)
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        if days > 0 { return "\(days)d \(hours)h" }
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func formatLatency(_ ms: Double?) -> String {
        guard let ms else { return "—" }
        return "\(Int(ms))ms"
    }

    private func formatPercent(_ pct: Double?) -> String {
        guard let pct else { return "—" }
        return "\(Int(pct))%"
    }

    private func formatTokens(_ count: Int?) -> String {
        guard let count else { return "—" }
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.0fK", Double(count) / 1_000) }
        return "\(count)"
    }

    private func loadStatus() async {
        isLoading = true
        loadError = false
        do {
            status = try await APIClient.shared.get("/api/openclaw-status")
        } catch {
            loadError = true
        }
        isLoading = false
    }
}
