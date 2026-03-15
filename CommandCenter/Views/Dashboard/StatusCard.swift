import SwiftUI

struct OpenClawStatus: Codable {
    let version: String?
    let uptime: String?
    let model: String?
    let sessions: Int?
}

struct StatusCard: View {
    @State private var status: OpenClawStatus?
    @State private var isLoading = true
    @State private var loadError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("OpenClaw", systemImage: "server.rack")
                .font(.headline)
                .foregroundStyle(AppColors.success)

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
                    statusItem(label: "Version", value: status.version ?? "—")
                    statusItem(label: "Uptime", value: status.uptime ?? "—")
                    statusItem(label: "Model", value: shortenModel(status.model))
                    statusItem(label: "Sessions", value: "\(status.sessions ?? 0)")
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: status != nil ? AppColors.success.opacity(0.08) : nil)
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

    private func shortenModel(_ model: String?) -> String {
        guard let model else { return "—" }
        return model
            .replacingOccurrences(of: "anthropic/", with: "")
            .replacingOccurrences(of: "openai/", with: "")
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
