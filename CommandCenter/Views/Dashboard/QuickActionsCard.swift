import SwiftUI

struct QuickActionsCard: View {
    let monitor: OpenClawMonitor
    @State private var runningAction: String?
    @State private var actionResult: (message: String, isError: Bool)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Quick Actions", systemImage: "bolt.fill")
                .font(.headline)
                .foregroundStyle(AppColors.accent)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                actionButton("Restart Gateway", icon: "arrow.clockwise", action: "gateway") {
                    try await APIClient.shared.postAction("/api/restart/gateway")
                    try? await Task.sleep(for: .seconds(3))
                    await monitor.refresh()
                }

                actionButton("Restart Server", icon: "arrow.clockwise", action: "server") {
                    try await APIClient.shared.postAction("/api/restart/server")
                    try? await Task.sleep(for: .seconds(3))
                    await monitor.refresh()
                }

                actionButton("Refresh Status", icon: "arrow.triangle.2.circlepath", action: "refresh") {
                    await monitor.refresh()
                }

                actionButton("Check Crises", icon: "exclamationmark.triangle", action: "crises") {
                    // Just triggers a chat message to Denny
                    let _: SendResponse = try await APIClient.shared.post(
                        "/api/chat/send",
                        body: ["content": "Give me a quick crisis and alert update."]
                    )
                }

                actionButton("Daily Summary", icon: "doc.text", action: "summary") {
                    let _: SendResponse = try await APIClient.shared.post(
                        "/api/chat/send",
                        body: ["content": "Give me a summary of today — weather, calendar, any alerts, and system status."]
                    )
                }

                actionButton("System Status", icon: "server.rack", action: "status") {
                    let _: SendResponse = try await APIClient.shared.post(
                        "/api/chat/send",
                        body: ["content": "Give me a quick system status update."]
                    )
                }
            }

            if let result = actionResult {
                Text(result.message)
                    .font(.caption2)
                    .foregroundStyle(result.isError ? AppColors.danger : AppColors.success)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
    }

    private func actionButton(
        _ title: String,
        icon: String,
        action: String,
        perform: @escaping () async throws -> Void
    ) -> some View {
        Button {
            guard runningAction == nil else { return }
            runningAction = action
            actionResult = nil
            HapticHelper.light()
            Task {
                do {
                    try await perform()
                    actionResult = (title + " complete", false)
                    HapticHelper.success()
                } catch {
                    actionResult = ("Failed: \(error.localizedDescription)", true)
                    HapticHelper.error()
                }
                runningAction = nil
                // Auto-dismiss result after 3s
                try? await Task.sleep(for: .seconds(3))
                if actionResult?.message.hasPrefix(title) == true || actionResult?.isError == true {
                    withAnimation { actionResult = nil }
                }
            }
        } label: {
            HStack(spacing: 6) {
                if runningAction == action {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(title)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(runningAction == action ? AppColors.muted : AppColors.text)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AppColors.muted.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(AppColors.border.opacity(0.5), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(runningAction != nil)
    }
}
