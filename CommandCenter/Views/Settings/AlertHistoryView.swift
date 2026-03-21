import SwiftUI

struct AlertHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var alerts = AlertHistory.shared.alerts

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGradient

                if alerts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.largeTitle)
                            .foregroundStyle(AppColors.muted)
                        Text("No alerts yet")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.muted)
                    }
                } else {
                    List {
                        ForEach(alerts) { alert in
                            HStack(alignment: .top, spacing: 10) {
                                Circle()
                                    .fill(alertColor(alert.level))
                                    .frame(width: 8, height: 8)
                                    .padding(.top, 6)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(alert.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(AppColors.text)
                                    Text(alert.body)
                                        .font(.caption)
                                        .foregroundStyle(AppColors.muted)
                                        .lineLimit(2)
                                    Text(formatDate(alert.timestamp))
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.muted.opacity(0.7))
                                }
                            }
                            .listRowBackground(AppColors.card)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Alert History")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.accent)
                }
                if !alerts.isEmpty {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Clear") {
                            AlertHistory.shared.clear()
                            alerts = []
                        }
                        .foregroundStyle(AppColors.danger)
                    }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 400, minHeight: 400)
        #endif
    }

    private func alertColor(_ level: String) -> Color {
        switch level {
        case "critical": return AppColors.danger
        case "warning": return AppColors.warning
        default: return AppColors.success
        }
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "h:mm a"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = "'Yesterday' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        return formatter.string(from: date)
    }
}
