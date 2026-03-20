import SwiftUI

/// Shows a timeline of recent system events derived from multiple API sources
struct ActivityFeedCard: View {
    let monitor: OpenClawMonitor
    @State private var recentMessages: [Message] = []
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Activity", systemImage: "list.bullet.rectangle")
                    .font(.headline)
                    .foregroundStyle(AppColors.accent)

                Spacer()

                Button {
                    Task { await loadActivity() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(AppColors.muted)
                }
                .buttonStyle(.plain)
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if events.isEmpty {
                Text("No recent activity")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.muted)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(events.prefix(8)) { event in
                        eventRow(event)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .task { await loadActivity() }
    }

    // MARK: - Build events from available data

    private var events: [ActivityEvent] {
        var items: [ActivityEvent] = []

        // Chat messages as events
        for msg in recentMessages.suffix(5) {
            let icon = msg.isUser ? "person.fill" : "🦩"
            let sfIcon = msg.isUser ? "person.fill" : "bubble.left.fill"
            let label = msg.isUser ? "You" : "Denny"
            let preview = String(msg.cleanedContent.prefix(60))
            items.append(ActivityEvent(
                id: "chat-\(msg.id)",
                icon: sfIcon,
                label: label,
                detail: preview,
                time: msg.parsedDate ?? Date.distantPast,
                color: msg.isUser ? AppColors.accent : .purple
            ))
        }

        // Agent activity from monitor
        if let agents = monitor.status?.agents {
            for agent in agents where agent.mostRecent?.value != nil {
                let time = Date(timeIntervalSince1970: (agent.mostRecent?.value ?? 0) / 1000)
                items.append(ActivityEvent(
                    id: "agent-\(agent.agentId ?? "")",
                    icon: "cpu",
                    label: agent.agentId ?? "Agent",
                    detail: "\(agent.sessionCount?.intValue ?? 0) sessions active",
                    time: time,
                    color: AppColors.success
                ))
            }
        }

        // Cron jobs (if we have last-run info, show them)
        if let cron = monitor.status?.cron, let jobs = cron.jobs {
            for job in jobs.prefix(3) where job.enabled == true {
                if let sched = job.schedule {
                    items.append(ActivityEvent(
                        id: "cron-\(job.stableId)",
                        icon: "clock.arrow.circlepath",
                        label: job.name ?? "Cron",
                        detail: formatSchedule(sched),
                        time: Date(), // No last-run time available
                        color: AppColors.warning,
                        isScheduled: true
                    ))
                }
            }
        }

        // Gateway status event
        if let gw = monitor.status?.gateway {
            let uptime = gw.uptime?.value ?? 0
            let startTime = Date(timeIntervalSinceNow: -(uptime / 1000))
            items.append(ActivityEvent(
                id: "gateway-start",
                icon: "server.rack",
                label: "Gateway",
                detail: gw.connected == true ? "Running" : "Offline",
                time: startTime,
                color: gw.connected == true ? AppColors.success : AppColors.danger
            ))
        }

        return items.sorted { $0.time > $1.time }
    }

    private func eventRow(_ event: ActivityEvent) -> some View {
        HStack(alignment: .top, spacing: 10) {
            // Timeline dot + line
            VStack(spacing: 0) {
                Circle()
                    .fill(event.color)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)
                Rectangle()
                    .fill(AppColors.border.opacity(0.4))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 8)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: event.icon)
                        .font(.caption2)
                        .foregroundStyle(event.color)

                    Text(event.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.text)

                    Spacer()

                    Text(event.isScheduled ? "scheduled" : relativeTime(event.time))
                        .font(.system(size: 9))
                        .foregroundStyle(AppColors.muted)
                }

                Text(event.detail)
                    .font(.caption)
                    .foregroundStyle(AppColors.muted)
                    .lineLimit(1)
            }
            .padding(.bottom, 10)
        }
    }

    private func loadActivity() async {
        do {
            let response: MessagesResponse = try await APIClient.shared.get(
                "/api/chat/history",
                queryItems: [URLQueryItem(name: "limit", value: "10")]
            )
            recentMessages = response.messages.filter { !$0.isHidden }
        } catch {
            // Silently fail — activity feed is supplementary
        }
        isLoading = false
    }

    private func relativeTime(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 0 { return "now" }
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86400 { return "\(seconds / 3600)h" }
        return "\(seconds / 86400)d"
    }

    private func formatSchedule(_ sched: CronSchedule) -> String {
        switch sched.kind {
        case "every":
            if let ms = sched.everyMs?.value {
                let sec = Int(ms / 1000)
                if sec >= 3600 { return "every \(sec / 3600)h" }
                return "every \(sec / 60)m"
            }
            return "recurring"
        default:
            return sched.expr ?? "scheduled"
        }
    }
}

struct ActivityEvent: Identifiable {
    let id: String
    let icon: String
    let label: String
    let detail: String
    let time: Date
    let color: Color
    var isScheduled: Bool = false
}
