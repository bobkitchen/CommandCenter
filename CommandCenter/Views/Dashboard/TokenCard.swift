import SwiftUI

struct TokenCard: View {
    let monitor: OpenClawMonitor

    private var status: OpenClawStatusResponse? { monitor.status }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Token Usage", systemImage: "chart.bar")
                    .font(.headline)
                    .foregroundStyle(AppColors.accent)

                Spacer()

                Text("Anthropic OAuth")
                    .font(.caption2)
                    .foregroundStyle(AppColors.muted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.muted.opacity(0.12), in: Capsule())
            }

            if monitor.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if let status {
                // Main session summary
                if let main = status.mainSession {
                    mainTokenRow(main)
                }

                Divider().overlay(AppColors.border)

                // Per-agent breakdown
                if let agents = status.agents, !agents.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("By Agent")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.text)

                        ForEach(agents.sorted(by: {
                            ($0.topSession?.totalTokens?.intValue ?? 0) > ($1.topSession?.totalTokens?.intValue ?? 0)
                        }), id: \.agentId) { agent in
                            agentTokenRow(agent)
                        }
                    }
                }

                // Session breakdown
                if let details = status.sessions?.details, !details.isEmpty {
                    Divider().overlay(AppColors.border)
                    sessionSummary(details)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func mainTokenRow(_ main: MainSessionInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Main Session")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.text)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                tokenStat("Input", value: main.inputTokens?.intValue, color: AppColors.accent)
                tokenStat("Output", value: main.outputTokens?.intValue, color: .purple)
                tokenStat("Cache Read", value: main.cacheRead?.intValue, color: AppColors.success)
                tokenStat("Cache Write", value: main.cacheWrite?.intValue, color: AppColors.warning)
            }

            // Total bar
            HStack {
                Text("Total")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColors.muted)
                Spacer()
                Text(formatTokens(main.totalTokens?.intValue))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.text)
            }
        }
    }

    private func agentTokenRow(_ agent: AgentSummary) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(agentColor(agent))
                .frame(width: 6, height: 6)

            Text(agent.agentId ?? "—")
                .font(.caption)
                .foregroundStyle(AppColors.text)
                .lineLimit(1)

            Spacer()

            if let top = agent.topSession {
                Text(formatTokens(top.totalTokens?.intValue))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.text)

                // Mini usage bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppColors.muted.opacity(0.15))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(contextColor(top.percentUsed?.value ?? 0))
                            .frame(width: geo.size.width * min(CGFloat(top.percentUsed?.value ?? 0) / 100, 1))
                    }
                }
                .frame(width: 40, height: 4)
            }

            Text("\(agent.sessionCount?.intValue ?? 0)s")
                .font(.caption2)
                .foregroundStyle(AppColors.muted)
                .frame(width: 22, alignment: .trailing)
        }
    }

    private func sessionSummary(_ details: [SessionDetail]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("All Sessions")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.text)

            let totalIn = details.compactMap(\.inputTokens?.intValue).reduce(0, +)
            let totalOut = details.compactMap(\.outputTokens?.intValue).reduce(0, +)
            let totalCacheR = details.compactMap(\.cacheRead?.intValue).reduce(0, +)
            let totalCacheW = details.compactMap(\.cacheWrite?.intValue).reduce(0, +)
            let grandTotal = totalIn + totalOut

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("In: \(formatTokens(totalIn))")
                        .font(.caption2)
                        .foregroundStyle(AppColors.accent)
                    Text("Cache R: \(formatTokens(totalCacheR))")
                        .font(.caption2)
                        .foregroundStyle(AppColors.success)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Out: \(formatTokens(totalOut))")
                        .font(.caption2)
                        .foregroundStyle(.purple)
                    Text("Cache W: \(formatTokens(totalCacheW))")
                        .font(.caption2)
                        .foregroundStyle(AppColors.warning)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Total")
                        .font(.caption2)
                        .foregroundStyle(AppColors.muted)
                    Text(formatTokens(grandTotal))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColors.text)
                }
            }

            // Cache efficiency
            if grandTotal > 0 {
                let cacheRate = Double(totalCacheR) / Double(grandTotal) * 100
                HStack(spacing: 4) {
                    Text("Cache hit rate:")
                        .font(.caption2)
                        .foregroundStyle(AppColors.muted)
                    Text(String(format: "%.0f%%", cacheRate))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(cacheRate > 50 ? AppColors.success : AppColors.warning)
                }
            }
        }
    }

    private func tokenStat(_ label: String, value: Int?, color: Color) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 3, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(AppColors.muted)
                Text(formatTokens(value))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.text)
            }
        }
    }

    private func formatTokens(_ count: Int?) -> String {
        guard let count else { return "0" }
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
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
}
