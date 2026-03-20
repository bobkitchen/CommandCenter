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
    let monitor: OpenClawMonitor
    @State private var expandedSection: Set<String> = []
    @State private var restartingGateway = false
    @State private var restartingServer = false
    @State private var restartError: String?

    private var status: OpenClawStatusResponse? { monitor.status }
    private var isConnected: Bool { monitor.isConnected }

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

            if monitor.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 80)
            } else if monitor.loadError {
                VStack(spacing: 6) {
                    ErrorRetryView(message: "Unable to connect") {
                        Task { await monitor.refresh() }
                    }
                    if let detail = monitor.errorDetail {
                        Text(detail)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(AppColors.muted)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else if let status {
                gatewaySection(status)

                if let main = status.mainSession {
                    contextBar(main)
                }

                // Expandable Sessions
                if let sessions = status.sessions, (sessions.total?.intValue ?? 0) > 0 {
                    sessionsSection(sessions)
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

                // Restart controls
                restartSection

                if let restartError {
                    Text(restartError)
                        .font(.caption2)
                        .foregroundStyle(AppColors.danger)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: isConnected ? AppColors.success.opacity(0.06) : nil)
    }

    // MARK: - Gateway

    @ViewBuilder
    private func gatewaySection(_ status: OpenClawStatusResponse) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            miniStat(label: "Model", value: shortenModel(status.model?.default))
            miniStat(label: "Uptime", value: formatUptime(status.gateway?.uptime?.value))
            miniStat(label: "Latency", value: formatLatency(status.gateway?.latency?.value))
            miniStat(label: "Memory", value: formatMemory(status.gateway?.memory?.value))
            miniStat(label: "Cron", value: "\(status.cron?.enabled?.intValue ?? 0)/\(status.cron?.total?.intValue ?? 0)")
            miniStat(label: "Last Active", value: OpenClawMonitor.relativeTime(from: status.mainSession?.lastActivity?.value))
        }
    }

    // MARK: - Context Bar with Trend

    @ViewBuilder
    private func contextBar(_ main: MainSessionInfo) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Main Context")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.text)

                // Trend indicator
                Image(systemName: trendIcon)
                    .font(.caption2)
                    .foregroundStyle(trendColor)

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
                        .animation(.easeOut(duration: 0.5), value: main.percentUsed?.value)
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

    // MARK: - Sessions (expandable)

    @ViewBuilder
    private func sessionsSection(_ sessions: SessionsSummary) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                HapticHelper.light()
                withAnimation(.easeOut(duration: 0.2)) {
                    toggleSection("sessions")
                }
            } label: {
                HStack {
                    Label("Sessions", systemImage: "rectangle.stack")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                    Spacer()
                    Text("\(sessions.total?.intValue ?? 0)")
                        .font(.caption2)
                        .foregroundStyle(AppColors.muted)
                    Image(systemName: expandedSection.contains("sessions") ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(AppColors.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            if expandedSection.contains("sessions"), let details = sessions.details {
                ForEach(details.sorted(by: {
                    ($0.percentUsed?.value ?? 0) > ($1.percentUsed?.value ?? 0)
                }), id: \.key) { session in
                    sessionRow(session)
                }
            }
        }
    }

    private func sessionRow(_ session: SessionDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(session.agent ?? session.key ?? "—")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)

                if let model = session.model {
                    Text(shortenModel(model))
                        .font(.system(size: 9))
                        .foregroundStyle(AppColors.muted)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(AppColors.muted.opacity(0.15), in: Capsule())
                }

                Spacer()

                Text("\(session.percentUsed?.intValue ?? 0)%")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(contextColor(session.percentUsed?.value ?? 0))
            }

            // Mini context bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(AppColors.muted.opacity(0.15))
                    RoundedRectangle(cornerRadius: 2)
                        .fill(contextColor(session.percentUsed?.value ?? 0))
                        .frame(width: geo.size.width * min(CGFloat(session.percentUsed?.value ?? 0) / 100.0, 1.0))
                }
            }
            .frame(height: 3)

            HStack(spacing: 8) {
                Text("Active \(OpenClawMonitor.relativeTime(from: session.lastActivity?.value))")
                    .font(.system(size: 9))
                    .foregroundStyle(AppColors.muted)

                Spacer()

                tokenLabel("In", value: session.inputTokens?.intValue)
                tokenLabel("Out", value: session.outputTokens?.intValue)
            }
        }
        .padding(8)
        .background(AppColors.muted.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Agents

    @ViewBuilder
    private func agentsSection(_ agents: [AgentSummary]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                HapticHelper.light()
                withAnimation(.easeOut(duration: 0.2)) {
                    toggleSection("agents")
                }
            } label: {
                HStack {
                    Label("Agents", systemImage: "cpu")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.text)
                    Spacer()
                    Text("\(agents.filter { ($0.sessionCount?.intValue ?? 0) > 0 }.count) active")
                        .font(.caption2)
                        .foregroundStyle(AppColors.muted)
                    Image(systemName: expandedSection.contains("agents") ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(AppColors.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            // Always show summary row for each agent
            ForEach(agents.filter { ($0.sessionCount?.intValue ?? 0) > 0 }, id: \.agentId) { agent in
                HStack(spacing: 8) {
                    Circle()
                        .fill(agentColor(agent))
                        .frame(width: 6, height: 6)

                    Text(agent.agentId ?? "—")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.text)

                    Spacer()

                    Text(OpenClawMonitor.relativeTime(from: agent.mostRecent?.value))
                        .font(.system(size: 9))
                        .foregroundStyle(AppColors.muted)

                    if let top = agent.topSession {
                        Text("\(top.percentUsed?.intValue ?? 0)%")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(contextColor(top.percentUsed?.value ?? 0))
                    }

                    Text("\(agent.sessionCount?.intValue ?? 0)s")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.muted)
                        .frame(width: 24, alignment: .trailing)
                }
            }

            // Expanded: show top session details per agent
            if expandedSection.contains("agents") {
                ForEach(agents.filter { $0.topSession != nil }, id: \.agentId) { agent in
                    if let top = agent.topSession {
                        HStack(spacing: 6) {
                            Text("  \(agent.agentId ?? "—") top:")
                                .font(.system(size: 9))
                                .foregroundStyle(AppColors.muted)

                            if let model = top.model {
                                Text(shortenModel(model))
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppColors.muted)
                            }

                            Spacer()

                            Text("\(formatTokens(top.totalTokens?.intValue)) tokens")
                                .font(.system(size: 9))
                                .foregroundStyle(AppColors.muted)

                            Text("\(top.percentUsed?.intValue ?? 0)%")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(contextColor(top.percentUsed?.value ?? 0))
                        }
                    }
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

                    Text(formatMemory(proc.memory?.value))
                        .font(.caption2)
                        .foregroundStyle(AppColors.muted)

                    Text(formatUptime(proc.uptime?.value))
                        .font(.caption2)
                        .foregroundStyle(AppColors.muted)
                }
            }
        }
    }

    // MARK: - Restart Controls

    private var restartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Controls", systemImage: "power")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.text)
                Spacer()
            }
            .padding(.top, 4)

            HStack(spacing: 10) {
                Button {
                    Task { await restartGateway() }
                } label: {
                    HStack(spacing: 6) {
                        if restartingGateway {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption2)
                        }
                        Text("Restart Gateway")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(AppColors.warning)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.warning.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(restartingGateway)

                Button {
                    Task { await restartServer() }
                } label: {
                    HStack(spacing: 6) {
                        if restartingServer {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption2)
                        }
                        Text("Restart Server")
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(AppColors.warning)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(AppColors.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(AppColors.warning.opacity(0.3), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
                .disabled(restartingServer)
            }
        }
    }

    private func restartGateway() async {
        restartingGateway = true
        restartError = nil
        HapticHelper.medium()
        do {
            try await APIClient.shared.postAction("/api/restart/gateway")
            HapticHelper.success()
            // Wait a moment then refresh status
            try? await Task.sleep(for: .seconds(3))
            await monitor.refresh()
        } catch {
            restartError = "Gateway restart failed: \(error.localizedDescription)"
            HapticHelper.error()
        }
        restartingGateway = false
    }

    private func restartServer() async {
        restartingServer = true
        restartError = nil
        HapticHelper.medium()
        do {
            try await APIClient.shared.postAction("/api/restart/server")
            HapticHelper.success()
            try? await Task.sleep(for: .seconds(3))
            await monitor.refresh()
        } catch {
            restartError = "Server restart failed: \(error.localizedDescription)"
            HapticHelper.error()
        }
        restartingServer = false
    }

    // MARK: - Helpers

    private func toggleSection(_ name: String) {
        if expandedSection.contains(name) {
            expandedSection.remove(name)
        } else {
            expandedSection.insert(name)
        }
    }

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

    private func formatMemory(_ bytes: Double?) -> String {
        guard let bytes, bytes > 0 else { return "—" }
        let mb = bytes / 1_048_576
        if mb > 1024 { return String(format: "%.1fGB", mb / 1024) }
        return String(format: "%.0fMB", mb)
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
        if age < 600_000 { return AppColors.success }
        if age < 3_600_000 { return AppColors.warning }
        return AppColors.muted
    }

    // MARK: - Trend

    private var trendIcon: String {
        switch monitor.contextTrend {
        case .rising: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .falling: return "arrow.down.right"
        }
    }

    private var trendColor: Color {
        switch monitor.contextTrend {
        case .rising: return AppColors.warning
        case .stable: return AppColors.muted
        case .falling: return AppColors.success
        }
    }

    // MARK: - Cron Formatting

    private func formatSchedule(_ sched: CronSchedule) -> String {
        switch sched.kind {
        case "cron":
            return describeCron(sched.expr)
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

    private func describeCron(_ expr: String?) -> String {
        guard let expr else { return "—" }
        let parts = expr.split(separator: " ").map(String.init)
        guard parts.count >= 5 else { return expr }

        let minute = parts[0]
        let hour = parts[1]
        let dom = parts[2]
        let month = parts[3]
        let dow = parts[4]

        let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

        var time = ""
        if hour != "*", let h = Int(hour), minute != "*", let m = Int(minute) {
            let ampm = h >= 12 ? "pm" : "am"
            let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            time = m == 0 ? "\(h12)\(ampm)" : String(format: "%d:%02d%@", h12, m, ampm)
        } else if hour != "*", let h = Int(hour) {
            let ampm = h >= 12 ? "pm" : "am"
            let h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h)
            time = "\(h12)\(ampm)"
        }

        if minute.hasPrefix("*/"), hour == "*", dom == "*", month == "*", dow == "*" {
            return "every \(minute.dropFirst(2))m"
        }
        if hour.hasPrefix("*/"), dom == "*", month == "*", dow == "*" {
            return "every \(hour.dropFirst(2))h"
        }
        if dom == "*", month == "*", dow == "*", !time.isEmpty {
            return "daily \(time)"
        }
        if dom == "*", month == "*", dow != "*", !time.isEmpty {
            let dayStr = dow.split(separator: ",").compactMap { d -> String? in
                guard let n = Int(d), n >= 0, n < 7 else { return String(d) }
                return dayNames[n]
            }.joined(separator: ",")
            return "\(dayStr) \(time)"
        }
        if dom != "*", month == "*", dow == "*", !time.isEmpty {
            return "\(ordinal(dom)) \(time)"
        }
        return expr
    }

    private func ordinal(_ s: String) -> String {
        guard let n = Int(s) else { return s }
        let suffix: String
        switch n % 10 {
        case 1 where n % 100 != 11: suffix = "st"
        case 2 where n % 100 != 12: suffix = "nd"
        case 3 where n % 100 != 13: suffix = "rd"
        default: suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}
