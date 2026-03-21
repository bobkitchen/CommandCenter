import SwiftUI

#if os(macOS)
struct MenuBarExtraView: View {
    let monitor: OpenClawMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Circle()
                    .fill(healthColor)
                    .frame(width: 8, height: 8)
                Text(monitor.healthSummary)
                    .font(.headline)
            }

            Divider()

            if let status = monitor.status {
                LabeledContent("Context", value: "\(Int(monitor.contextPercent))%")
                LabeledContent("Model", value: (status.model?.default ?? "—").replacingOccurrences(of: "anthropic/", with: "").replacingOccurrences(of: "claude-", with: ""))
                LabeledContent("Agents", value: "\(status.agents?.count ?? 0)")
                LabeledContent("Updated", value: monitor.lastUpdatedText)
            } else if monitor.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
            } else {
                Text("No data available")
                    .foregroundStyle(.secondary)
            }

            Divider()

            Button("Open Command Center") {
                NSApplication.shared.activate(ignoringOtherApps: true)
                if let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain }) {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            Button("Refresh") {
                Task { await monitor.refresh() }
            }

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding()
        .frame(width: 280)
    }

    private var healthColor: Color {
        switch monitor.healthState {
        case .healthy: return AppColors.success
        case .warning: return AppColors.warning
        case .critical: return AppColors.danger
        }
    }
}
#endif
