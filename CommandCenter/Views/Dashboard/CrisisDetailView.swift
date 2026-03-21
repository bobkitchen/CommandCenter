import SwiftUI

struct CrisisDetailView: View {
    let crisis: Crisis
    @Environment(\.dismiss) private var dismiss
    @State private var askingDenny = false
    @State private var dennyAsked = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGradient

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Status header
                        HStack(spacing: 12) {
                            Circle()
                                .fill(crisis.levelColor)
                                .frame(width: 14, height: 14)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(crisis.name)
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(AppColors.text)

                                if let level = crisis.level {
                                    Text(level.uppercased())
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(crisis.levelColor)
                                }
                            }

                            Spacer()

                            if let status = crisis.status {
                                Text(status)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(AppColors.text)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(AppColors.muted.opacity(0.15), in: Capsule())
                            }
                        }

                        // Summary
                        if let summary = crisis.summary {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Summary")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.muted)
                                Text(summary)
                                    .font(.body)
                                    .foregroundStyle(AppColors.text)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.card, in: RoundedRectangle(cornerRadius: 12))
                        }

                        // Details
                        if let details = crisis.details {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Details")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.muted)
                                Text(details)
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.text)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.card, in: RoundedRectangle(cornerRadius: 12))
                        }

                        // Metadata
                        VStack(alignment: .leading, spacing: 8) {
                            if let source = crisis.source {
                                HStack {
                                    Image(systemName: "info.circle")
                                        .foregroundStyle(AppColors.muted)
                                    Text("Source: \(source)")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.muted)
                                }
                            }
                            if let created = crisis.createdAt {
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundStyle(AppColors.muted)
                                    Text("Created: \(created)")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.muted)
                                }
                            }
                            if let updated = crisis.updated {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                        .foregroundStyle(AppColors.muted)
                                    Text("Updated: \(updated)")
                                        .font(.caption)
                                        .foregroundStyle(AppColors.muted)
                                }
                            }
                        }

                        // Ask Denny
                        Button {
                            askDenny()
                        } label: {
                            HStack(spacing: 8) {
                                if askingDenny {
                                    ProgressView().controlSize(.small)
                                } else if dennyAsked {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AppColors.success)
                                } else {
                                    Text("🦩")
                                }
                                Text(dennyAsked ? "Sent to Chat" : "Ask Denny About This")
                                    .font(.headline)
                            }
                            .foregroundStyle(dennyAsked ? AppColors.success : AppColors.text)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                dennyAsked ? AppColors.success.opacity(0.1) : AppColors.accent.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 14)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(askingDenny || dennyAsked)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Crisis")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 400)
        #endif
    }

    private func askDenny() {
        askingDenny = true
        HapticHelper.light()
        Task {
            do {
                let _: SendResponse = try await APIClient.shared.post(
                    "/api/chat/send",
                    body: ["content": "Tell me about the crisis: \(crisis.name). What's the current status, what caused it, and what should I do?"]
                )
                dennyAsked = true
                HapticHelper.success()
            } catch {
                HapticHelper.error()
            }
            askingDenny = false
        }
    }
}
