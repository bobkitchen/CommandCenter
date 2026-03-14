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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("OpenClaw", systemImage: "server.rack")
                .font(.headline)
                .foregroundStyle(AppColors.success)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if let status {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    statusItem(label: "Version", value: status.version ?? "—")
                    statusItem(label: "Uptime", value: status.uptime ?? "—")
                    statusItem(label: "Model", value: shortenModel(status.model))
                    statusItem(label: "Sessions", value: "\(status.sessions ?? 0)")
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(AppColors.danger)
                    Text("Unable to connect")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.muted)
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
        // "anthropic/claude-opus-4-6" → "claude-opus-4"
        return model
            .replacingOccurrences(of: "anthropic/", with: "")
            .replacingOccurrences(of: "openai/", with: "")
    }

    private func loadStatus() async {
        do {
            status = try await APIClient.shared.get("/api/openclaw-status")
        } catch {}
        isLoading = false
    }
}
