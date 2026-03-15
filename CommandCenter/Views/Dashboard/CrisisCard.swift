import SwiftUI

struct CrisisCard: View {
    @State private var crises: [Crisis] = []
    @State private var isLoading = true
    @State private var loadError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Active Crises", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(AppColors.danger)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if loadError {
                ErrorRetryView(message: "Unable to load crises") {
                    Task { await loadCrises() }
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else if crises.isEmpty {
                Text("No active crises")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.muted)
            } else {
                VStack(spacing: 10) {
                    ForEach(crises) { crisis in
                        crisisRow(crisis)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: crises.contains(where: { $0.level?.lowercased() == "critical" }) ? AppColors.danger.opacity(0.15) : nil)
        .task { await loadCrises() }
    }

    private func crisisRow(_ crisis: Crisis) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(crisis.levelColor)
                .frame(width: 10, height: 10)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(crisis.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.text)

                    Spacer()

                    if let level = crisis.level {
                        Text(level.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(crisis.levelColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(crisis.levelColor.opacity(0.15), in: Capsule())
                    }
                }

                if let summary = crisis.summary {
                    Text(summary)
                        .font(.caption)
                        .foregroundStyle(AppColors.muted)
                        .lineLimit(2)
                }
            }
        }
    }

    private func loadCrises() async {
        isLoading = true
        loadError = false
        do {
            let response: CrisesResponse = try await APIClient.shared.get("/api/crises")
            crises = response.crises
        } catch {
            loadError = true
        }
        isLoading = false
    }
}
