import SwiftUI

// MARK: - Flexible Codable helpers

/// Decodes a value that might be String, Int, or Double from the API
struct FlexString: Codable {
    let value: String
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) { value = s }
        else if let d = try? c.decode(Double.self) { value = String(d) }
        else if let b = try? c.decode(Bool.self) { value = String(b) }
        else { value = "" }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }
}

/// Decodes a number that might be Int, Double, or String from the API
struct FlexNumber: Codable {
    let value: Double
    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let d = try? c.decode(Double.self) { value = d }
        else if let s = try? c.decode(String.self) { value = Double(s) ?? 0 }
        else { value = 0 }
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(value)
    }
    var intValue: Int { Int(value) }
}

// MARK: - API Response Models (matches /api/openclaw-status)

struct OpenClawStatusResponse: Codable {
    let timestamp: FlexNumber?
    let fetchTime: FlexNumber?
    let gateway: GatewayStatus?
    let model: ModelInfo?
    let mainSession: MainSessionInfo?
    let sessions: SessionsSummary?
    let agents: [AgentSummary]?
    let heartbeat: HeartbeatInfo?
    let channels: [String]?
    let cron: CronInfo?
    let pm2: PM2Info?
}

struct GatewayStatus: Codable {
    let connected: Bool?
    let latency: FlexNumber?
    let uptime: FlexNumber?
    let pid: FlexNumber?
    let memory: FlexNumber?
    let cpu: FlexNumber?
    let restarts: FlexNumber?
}

struct ModelInfo: Codable {
    let `default`: String?
    let contextWindow: FlexNumber?
}

struct MainSessionInfo: Codable {
    let percentUsed: FlexNumber?
    let totalTokens: FlexNumber?
    let remainingTokens: FlexNumber?
    let contextTokens: FlexNumber?
    let inputTokens: FlexNumber?
    let outputTokens: FlexNumber?
    let cacheRead: FlexNumber?
    let cacheWrite: FlexNumber?
    let model: String?
    let lastActivity: FlexNumber?
}

struct SessionsSummary: Codable {
    let total: FlexNumber?
    let details: [SessionDetail]?
}

struct SessionDetail: Codable {
    let key: String?
    let agent: String?
    let model: String?
    let percentUsed: FlexNumber?
    let totalTokens: FlexNumber?
    let remainingTokens: FlexNumber?
    let inputTokens: FlexNumber?
    let outputTokens: FlexNumber?
    let cacheRead: FlexNumber?
    let cacheWrite: FlexNumber?
    let lastActivity: FlexNumber?
    let age: FlexNumber?
}

struct AgentSummary: Codable {
    let agentId: String?
    let sessionCount: FlexNumber?
    let mostRecent: FlexNumber?
    let topSession: AgentTopSession?
}

struct AgentTopSession: Codable {
    let key: String?
    let percentUsed: FlexNumber?
    let totalTokens: FlexNumber?
    let model: String?
}

struct HeartbeatInfo: Codable {
    let active: [HeartbeatAgent]?
    let total: FlexNumber?
}

struct HeartbeatAgent: Codable {
    let agentId: String?
    let every: FlexString?
}

struct CronInfo: Codable {
    let total: FlexNumber?
    let enabled: FlexNumber?
    let jobs: [CronJob]?
}

struct CronJob: Codable, Identifiable {
    let id: String?
    let name: String?
    let enabled: Bool?
    let schedule: CronSchedule?

    var stableId: String { id ?? UUID().uuidString }
}

struct CronSchedule: Codable {
    let kind: String?
    let expr: String?
    let tz: String?
    let everyMs: FlexNumber?
}

struct PM2Info: Codable {
    let processes: [PM2Process]?
    let commandCenter: PM2ProcessStatus?
}

struct PM2Process: Codable {
    let name: String?
    let pid: FlexNumber?
    let status: String?
    let uptime: FlexNumber?
    let memory: FlexNumber?
    let cpu: FlexNumber?
    let restarts: FlexNumber?
}

struct PM2ProcessStatus: Codable {
    let status: String?
    let uptime: FlexNumber?
    let memory: FlexNumber?
    let restarts: FlexNumber?
}

// MARK: - StatusCard View

struct StatusCard: View {
    @State private var status: OpenClawStatusResponse?
    @State private var isLoading = true
    @State private var loadError = false
    @State private var errorDetail: String?
    @State private var expandedSection: String?

    private var isConnected: Bool {
        status?.gateway?.connected ?? false
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
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
                        Text("Online")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppColors.success)
                    }
                }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if loadError {
                VStack(spacing: 6) {
                    ErrorRetryView(message: "Unable to connect") {
                        Task { await loadStatus() }
                    }
                    if let detail = errorDetail {
                        Text(detail)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(AppColors.muted)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else if let status {
                // Gateway stats
                gatewaySection(status)

                // Context usage bar
                if let main = status.mainSession {
                    contextBar(main)
                }

                // Agents
                if let agents = status.agents, !agents.isEmpty {
                    agentsSection(agents)
                }

                // Cron jobs
                if let cron = status.cron, (cron.total?.intValue ?? 0) > 0 {
                    cronSection(cron)
                }

                // PM2 processes
                if let pm2 = status.pm2, let procs = pm2.processes, !procs.isEmpty {
                    pm2Section(procs)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: isConnected ? AppColors.success.opacity(0.06) : nil)
        .task { await loadStatus() }
    }

    // MARK: - Gateway

    @ViewBuilder
    private func gatewaySection(_ status: OpenClawStatusResponse) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            miniStat(label: "Model", value: shortenModel(status.model?.default))
            miniStat(label: "Uptime", value: formatUptime(status.gateway?.uptime?.value))
            miniStat(label: "Latency", value: formatLatency(status.gateway?.latency?.value))
            miniStat(label: "Sessions", value: "\(status.sessions?.total?.intValue ?? 0)")
            miniStat(label: "Cron", value: "\(status.cron?.enabled?.intValue ?? 0)/\(status.cron?.total?.intValue ?? 0)")
            miniStat(label: "Heartbeats", value: "\(status.heartbeat?.total?.intValue ?? 0)")
        }
    }

    // MARK: - Context Bar

    @ViewBuilder
    private func contextBar(_ main: MainSessionInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Main Context")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.text)
                Spacer()
                Text("\(main.percentUsed?.intValue ?? 0)%")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(contextColor(main.percentUsed?.value ?? 0))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.muted.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(contextColor(main.percentUsed?.value ?? 0))
                        .frame(width: geo.size.width * min(CGFloat(main.percentUsed?.value ?? 0) / 100.0, 1.0))
                }
            }
            .frame(height: 6)

            HStack(spacing: 12) {
                tokenLabel("In", value: main.inputTokens?.intValue)
                tokenLabel("Out", value: main.outputTokens?.intValue)
                tokenLabel("Cache R", value: main.cacheRead?.intValue)
                tokenLabel("Cache W", value: main.cacheWrite?.intValue)
            }
        }
        .padding(10)
        .background(AppColors.muted.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Agents

    @ViewBuilder
    private func agentsSection(_ agents: [AgentSummary]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Agents", icon: "cpu", count: agents.count)

            ForEach(agents.filter { ($0.sessionCount?.intValue ?? 0) > 0 }, id: \.agentId) { agent in
                HStack(spacing: 8) {
                    Circle()
                        .fill(agentColor(agent))
                        .frame(width: 6, height: 6)

                    Text(agent.agentId ?? "—")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.text)

                    Spacer()

                    if let top = agent.topSession, let model = top.model {
                        Text(shortenModel(model))
                            .font(.caption2)
                            .foregroundStyle(AppColors.muted)
                    }

                    Text("\(agent.sessionCount?.intValue ?? 0)s")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.muted)
                        .frame(width: 24, alignment: .trailing)
                }
            }
        }
    }

    // MARK: - Cron

    @ViewBuilder
    private func cronSection(_ cron: CronInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Cron Jobs", icon: "clock.arrow.circlepath",
                          count: cron.enabled?.intValue ?? 0, total: cron.total?.intValue ?? 0)

            if let jobs = cron.jobs?.filter({ $0.enabled == true }).prefix(5) {
                ForEach(Array(jobs), id: \.stableId) { job in
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption2)
                            .foregroundStyle(AppColors.success)

                        Text(job.name ?? "Unnamed")
                            .font(.caption)
                            .foregroundStyle(AppColors.text)
                            .lineLimit(1)

                        Spacer()

                        if let sched = job.schedule {
                            Text(formatSchedule(sched))
                                .font(.caption2)
                                .foregroundStyle(AppColors.muted)
                        }
                    }
                }
            }
        }
    }

    // MARK: - PM2

    @ViewBuilder
    private func pm2Section(_ processes: [PM2Process]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader("Processes", icon: "gearshape.2", count: processes.count)

            ForEach(processes, id: \.name) { proc in
                HStack(spacing: 8) {
                    Circle()
                        .fill(proc.status == "online" ? AppColors.success : AppColors.danger)
                        .frame(width: 6, height: 6)

                    Text(proc.name ?? "—")
                        .font(.caption)
                        .foregroundStyle(AppColors.text)

                    Spacer()

                    if let pid = proc.pid {
                        Text("PID \(pid.intValue)")
                            .font(.caption2)
                            .foregroundStyle(AppColors.muted)
                    }

                    Text(formatUptime(proc.uptime?.value))
                        .font(.caption2)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    // MARK: - Helpers

    private func miniStat(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColors.muted)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sectionHeader(_ title: String, icon: String, count: Int, total: Int? = nil) -> some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.text)
            Spacer()
            if let total {
                Text("\(count)/\(total)")
                    .font(.caption2)
                    .foregroundStyle(AppColors.muted)
            } else {
                Text("\(count)")
                    .font(.caption2)
                    .foregroundStyle(AppColors.muted)
            }
        }
        .padding(.top, 4)
    }

    private func tokenLabel(_ label: String, value: Int?) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(AppColors.muted)
            Text(formatTokens(value))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(AppColors.text)
        }
    }

    private func shortenModel(_ model: String?) -> String {
        guard let model else { return "—" }
        return model
            .replacingOccurrences(of: "anthropic/", with: "")
            .replacingOccurrences(of: "openai/", with: "")
            .replacingOccurrences(of: "claude-", with: "")
    }

    private func formatUptime(_ ms: Double?) -> String {
        guard let ms, ms > 0 else { return "—" }
        let seconds = Int(ms / 1000)
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let minutes = (seconds % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func formatLatency(_ ms: Double?) -> String {
        guard let ms else { return "—" }
        return "\(Int(ms))ms"
    }

    private func formatTokens(_ count: Int?) -> String {
        guard let count else { return "0" }
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.0fK", Double(count) / 1_000) }
        return "\(count)"
    }

    private func contextColor(_ pct: Double) -> Color {
        if pct > 80 { return AppColors.danger }
        if pct > 50 { return AppColors.warning }
        return AppColors.success
    }

    private func agentColor(_ agent: AgentSummary) -> Color {
        guard let recent = agent.mostRecent?.value else { return AppColors.muted }
        let age = Date().timeIntervalSince1970 * 1000 - recent
        if age < 600_000 { return AppColors.success }      // < 10 min
        if age < 3_600_000 { return AppColors.warning }    // < 1 hour
        return AppColors.muted
    }

    private func formatSchedule(_ sched: CronSchedule) -> String {
        switch sched.kind {
        case "cron":
            return sched.expr ?? "—"
        case "every":
            if let ms = sched.everyMs?.value {
                return "every \(formatUptime(ms))"
            }
            return "recurring"
        case "at":
            return "one-shot"
        default:
            return sched.kind ?? "—"
        }
    }

    private func loadStatus() async {
        isLoading = true
        loadError = false
        errorDetail = nil
        do {
            status = try await APIClient.shared.get("/api/openclaw-status")
            print("[StatusCard] OK: connected=\(isConnected), model=\(status?.model?.default ?? "nil")")
        } catch let apiError as APIError {
            loadError = true
            errorDetail = apiError.errorDescription
            print("[StatusCard] APIError: \(apiError.errorDescription ?? "unknown")")
        } catch let decodingError as DecodingError {
            loadError = true
            errorDetail = describeDecodingError(decodingError)
            print("[StatusCard] DecodingError: \(errorDetail ?? "unknown")")
        } catch {
            loadError = true
            errorDetail = error.localizedDescription
            print("[StatusCard] Error: \(error)")
        }
        isLoading = false
    }

    private func describeDecodingError(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let ctx):
            return "Missing key '\(key.stringValue)' at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case .typeMismatch(let type, let ctx):
            return "Type mismatch for \(type) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case .valueNotFound(let type, let ctx):
            return "Null value for \(type) at \(ctx.codingPath.map(\.stringValue).joined(separator: "."))"
        case .dataCorrupted(let ctx):
            return "Data corrupted: \(ctx.debugDescription)"
        @unknown default:
            return "Unknown decoding error"
        }
    }
}
