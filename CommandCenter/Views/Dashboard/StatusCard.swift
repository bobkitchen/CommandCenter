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
    @State private var showDetails = false
    @State private var restartingGateway = false
    @State private var restartingServer = false
    @State private var restartError: String?

    private var status: OpenClawStatusResponse? { monitor.status }
    private var isConnected: Bool { monitor.isConnected }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if monitor.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
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
                // === TOP: Big glanceable stats ===
                topStats(status)

                // === MIDDLE: Process health dots ===
                if let procs = status.pm2?.processes, !procs.isEmpty {
                    processRow(procs)
                }

                // === Cron summary (one line) ===
                if let cron = status.cron, (cron.enabled?.intValue ?? 0) > 0 {
                    cronSummary(cron)
                }

                // === BOTTOM: Controls & details toggle ===
                HStack(spacing: 10) {
                    restartButton("Gateway", isLoading: restartingGateway) {
                        Task { await restartGateway() }
                    }
                    restartButton("Server", isLoading: restartingServer) {
                        Task { await restartServer() }
                    }

                    Spacer()

                    Button {
                        HapticHelper.light()
                        withAnimation(.easeOut(duration: 0.2)) {
                            showDetails.toggle()
                        }
                    } label: {
                        Image(systemName: showDetails ? "chevron.up" : "ellipsis")
                            .font(.caption)
                            .foregroundStyle(AppColors.muted)
                            .frame(width: 32, height: 32)
                            .background(AppColors.muted.opacity(0.1), in: Circle())
                    }
                    .buttonStyle(.plain)
                }

                if let restartError {
                    Text(restartError)
                        .font(.caption2)
                        .foregroundStyle(AppColors.danger)
                }

                // === EXPANDED: Detail sections ===
                if showDetails {
                    detailsSection(status)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: isConnected ? AppColors.success.opacity(0.06) : nil)
    }

    // MARK: - Top Stats

    @ViewBuilder
    private func topStats(_ status: OpenClawStatusResponse) -> some View {
        HStack(spacing: 0) {
            // Uptime — big number
            VStack(alignment: .leading, spacing: 2) {
                Text("UPTIME")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.muted)
                Text(formatUptimeBig(status.gateway?.uptime?.value))
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .foregroundStyle(AppColors.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Model — prominent
            VStack(alignment: .leading, spacing: 2) {
                Text("MODEL")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.muted)
                Text(friendlyModel(status.model?.default))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Latency
            VStack(alignment: .trailing, spacing: 2) {
                Text("LATENCY")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(AppColors.muted)
                HStack(spacing: 4) {
                    Circle()
                        .fill(latencyColor(status.gateway?.latency?.value))
                        .frame(width: 6, height: 6)
                    Text(formatLatency(status.gateway?.latency?.value))
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(AppColors.text)
                }
            }
        }
    }

    // MARK: - Process Health Row

    @ViewBuilder
    private func processRow(_ processes: [PM2Process]) -> some View {
        HStack(spacing: 12) {
            ForEach(processes, id: \.name) { proc in
                HStack(spacing: 5) {
                    Circle()
                        .fill(proc.status == "online" ? AppColors.success : AppColors.danger)
                        .frame(width: 8, height: 8)
                    Text(proc.name ?? "—")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.text)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(AppColors.muted.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Cron Summary

    @ViewBuilder
    private func cronSummary(_ cron: CronInfo) -> some View {
        let enabled = cron.enabled?.intValue ?? 0
        let total = cron.total?.intValue ?? 0
        let nextJob = cron.jobs?.filter { $0.enabled == true }.first

        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption)
                .foregroundStyle(AppColors.muted)

            Text("\(enabled)/\(total) jobs active")
                .font(.caption)
                .foregroundStyle(AppColors.text)

            if let job = nextJob, let sched = job.schedule {
                Text("·")
                    .foregroundStyle(AppColors.muted)
                Text("\(job.name ?? "Job"): \(formatSchedule(sched))")
                    .font(.caption)
                    .foregroundStyle(AppColors.muted)
                    .lineLimit(1)
            }

            Spacer()
        }
    }

    // MARK: - Restart Button

    private func restartButton(_ label: String, isLoading: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isLoading {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10))
                }
                Text(label)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(AppColors.warning)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColors.warning.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }

    // MARK: - Details (Expanded)

    @ViewBuilder
    private func detailsSection(_ status: OpenClawStatusResponse) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider().overlay(AppColors.border)

            // Gateway details
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                detailStat("Memory", formatMemory(status.gateway?.memory?.value))
                detailStat("Restarts", "\(status.gateway?.restarts?.intValue ?? 0)")
                detailStat("Last Active", OpenClawMonitor.relativeTime(from: status.mainSession?.lastActivity?.value))
            }

            // Active agents
            if let agents = status.agents?.filter({ ($0.sessionCount?.intValue ?? 0) > 0 }), !agents.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .font(.caption2)
                        .foregroundStyle(AppColors.muted)
                    Text("\(agents.count) agent\(agents.count == 1 ? "" : "s") active")
                        .font(.caption)
                        .foregroundStyle(AppColors.text)

                    Spacer()

                    Text("\(status.sessions?.total?.intValue ?? 0) sessions")
                        .font(.caption)
                        .foregroundStyle(AppColors.muted)
                }
            }

            // Cron job list
            if let jobs = status.cron?.jobs?.filter({ $0.enabled == true }) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(jobs.prefix(5)), id: \.stableId) { job in
                        HStack(spacing: 6) {
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

            // PM2 process details
            if let procs = status.pm2?.processes {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(procs, id: \.name) { proc in
                        HStack(spacing: 8) {
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
        }
    }

    // MARK: - Detail stat

    private func detailStat(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(AppColors.muted)
            Text(value)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Restart Actions

    private func restartGateway() async {
        restartingGateway = true
        restartError = nil
        HapticHelper.medium()
        do {
            try await APIClient.shared.postAction("/api/restart/gateway")
            HapticHelper.success()
            try? await Task.sleep(for: .seconds(3))
            await monitor.refresh()
        } catch {
            restartError = "Gateway: \(error.localizedDescription)"
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
            restartError = "Server: \(error.localizedDescription)"
            HapticHelper.error()
        }
        restartingServer = false
    }

    // MARK: - Formatters

    private func friendlyModel(_ model: String?) -> String {
        guard let model else { return "—" }
        return model
            .replacingOccurrences(of: "anthropic/", with: "")
            .replacingOccurrences(of: "openai/", with: "")
            .replacingOccurrences(of: "claude-", with: "Claude ")
            .replacingOccurrences(of: "-latest", with: "")
            .replacingOccurrences(of: "-", with: " ")
            .capitalized
    }

    private func formatUptimeBig(_ ms: Double?) -> String {
        guard let ms, ms > 0 else { return "—" }
        let seconds = Int(ms / 1000)
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        if days > 0 { return "\(days)d \(hours)h" }
        let minutes = (seconds % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    private func formatUptime(_ ms: Double?) -> String {
        formatUptimeBig(ms)
    }

    private func formatLatency(_ ms: Double?) -> String {
        guard let ms else { return "—" }
        return "\(Int(ms))ms"
    }

    private func latencyColor(_ ms: Double?) -> Color {
        guard let ms else { return AppColors.muted }
        if ms < 200 { return AppColors.success }
        if ms < 500 { return AppColors.warning }
        return AppColors.danger
    }

    private func formatMemory(_ bytes: Double?) -> String {
        guard let bytes, bytes > 0 else { return "—" }
        let mb = bytes / 1_048_576
        if mb > 1024 { return String(format: "%.1fGB", mb / 1024) }
        return String(format: "%.0fMB", mb)
    }

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
