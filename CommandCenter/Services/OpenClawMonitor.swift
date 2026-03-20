import Foundation
import WidgetKit

@MainActor @Observable
final class OpenClawMonitor {
    var status: OpenClawStatusResponse?
    var isLoading = true
    var loadError = false
    var errorDetail: String?
    var lastUpdated: Date?

    /// Previous context % for trend detection
    private var previousContextPercent: Double?
    private var pollTask: Task<Void, Never>?

    // MARK: - Derived State

    var isConnected: Bool { status?.gateway?.connected ?? false }

    var contextPercent: Double { status?.mainSession?.percentUsed?.value ?? 0 }

    var contextTrend: ContextTrend {
        guard let prev = previousContextPercent else { return .stable }
        let diff = contextPercent - prev
        if diff > 1.5 { return .rising }
        if diff < -1.5 { return .falling }
        return .stable
    }

    var healthState: HealthState {
        if loadError || !isConnected { return .critical }
        if contextPercent > 80 { return .warning }
        if let procs = status?.pm2?.processes,
           procs.contains(where: { $0.status != "online" }) {
            return .warning
        }
        return .healthy
    }

    /// Human-readable summary for the health banner
    var healthSummary: String {
        switch healthState {
        case .critical:
            if loadError { return "Connection Failed" }
            return "Gateway Offline"
        case .warning:
            var issues: [String] = []
            if contextPercent > 80 { issues.append("Context at \(Int(contextPercent))%") }
            if let procs = status?.pm2?.processes {
                let down = procs.filter { $0.status != "online" }
                if !down.isEmpty {
                    issues.append("\(down.count) process\(down.count == 1 ? "" : "es") down")
                }
            }
            return issues.joined(separator: " · ")
        case .healthy:
            return "All Systems Operational"
        }
    }

    /// Time since last successful update
    var lastUpdatedText: String {
        guard let lastUpdated else { return "" }
        let seconds = Int(Date().timeIntervalSince(lastUpdated))
        if seconds < 5 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }

    // MARK: - Lifecycle

    func startMonitoring() {
        stopMonitoring()
        pollTask = Task { [weak self] in
            await self?.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled else { break }
                await self?.refresh()
            }
        }
    }

    func stopMonitoring() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        if status != nil {
            previousContextPercent = contextPercent
        }
        do {
            status = try await APIClient.shared.get("/api/openclaw-status")
            loadError = false
            errorDetail = nil
            lastUpdated = Date()
            NotificationService.shared.checkForAlerts(monitor: self)
            updateWidgetData()
        } catch let apiError as APIError {
            loadError = true
            errorDetail = apiError.errorDescription
        } catch let decodingError as DecodingError {
            loadError = true
            errorDetail = describeDecodingError(decodingError)
        } catch {
            loadError = true
            errorDetail = error.localizedDescription
        }
        isLoading = false
        // Also check alerts on error state
        if loadError {
            NotificationService.shared.checkForAlerts(monitor: self)
        }
    }

    // MARK: - Helpers

    enum ContextTrend { case rising, stable, falling }
    enum HealthState { case healthy, warning, critical }

    /// Convert epoch milliseconds to relative time string
    static func relativeTime(from epochMs: Double?) -> String {
        guard let epochMs, epochMs > 0 else { return "—" }
        let date = Date(timeIntervalSince1970: epochMs / 1000)
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 0 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }

    /// Push current status to the home screen widget via App Groups
    private func updateWidgetData() {
        guard let status else { return }
        let uptime = status.gateway?.uptime?.value ?? 0
        let seconds = Int(uptime / 1000)
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let uptimeStr = days > 0 ? "\(days)d \(hours)h" : "\(hours)h"

        let model = (status.model?.default ?? "—")
            .replacingOccurrences(of: "anthropic/", with: "")
            .replacingOccurrences(of: "claude-", with: "")

        let data = WidgetData(
            isConnected: isConnected,
            contextPercent: contextPercent,
            healthSummary: healthSummary,
            model: model,
            uptime: uptimeStr,
            agentCount: status.agents?.count ?? 0,
            lastUpdated: Date()
        )
        data.save()
        WidgetCenter.shared.reloadAllTimelines()
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
