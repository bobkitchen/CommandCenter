import SwiftUI

struct HealthBanner: View {
    let monitor: OpenClawMonitor
    @State private var pulseOpacity: Double = 1.0

    var body: some View {
        HStack(spacing: 10) {
            // Status dot with pulse animation for critical
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
                .opacity(monitor.healthState == .critical ? pulseOpacity : 1.0)
                .animation(
                    monitor.healthState == .critical
                        ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: pulseOpacity
                )
                .onAppear {
                    if monitor.healthState == .critical { pulseOpacity = 0.3 }
                }
                .onChange(of: monitor.healthState) { _, newValue in
                    pulseOpacity = newValue == .critical ? 0.3 : 1.0
                }

            // Summary text
            VStack(alignment: .leading, spacing: 1) {
                Text(monitor.healthSummary)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(summaryColor)
                    .lineLimit(1)

                if !monitor.lastUpdatedText.isEmpty {
                    Text("Updated \(monitor.lastUpdatedText)")
                        .font(.caption2)
                        .foregroundStyle(AppColors.muted)
                }
            }

            Spacer()

            // Context gauge (compact)
            if monitor.isConnected, let main = monitor.status?.mainSession {
                contextGauge(main)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(bannerBackground, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor.opacity(0.4), lineWidth: 0.5)
        )
    }

    // MARK: - Context Gauge

    private func contextGauge(_ main: MainSessionInfo) -> some View {
        HStack(spacing: 6) {
            // Trend arrow
            Image(systemName: trendIcon)
                .font(.caption2)
                .foregroundStyle(trendColor)

            // Circular progress
            ZStack {
                Circle()
                    .stroke(AppColors.muted.opacity(0.2), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: min(monitor.contextPercent / 100.0, 1.0))
                    .stroke(contextColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                Text("\(Int(monitor.contextPercent))")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(contextColor)
            }
            .frame(width: 28, height: 28)
        }
    }

    // MARK: - Styling

    private var dotColor: Color {
        switch monitor.healthState {
        case .healthy: return AppColors.success
        case .warning: return AppColors.warning
        case .critical: return AppColors.danger
        }
    }

    private var summaryColor: Color {
        switch monitor.healthState {
        case .healthy: return AppColors.text
        case .warning: return AppColors.warning
        case .critical: return AppColors.danger
        }
    }

    private var borderColor: Color {
        switch monitor.healthState {
        case .healthy: return AppColors.border
        case .warning: return AppColors.warning
        case .critical: return AppColors.danger
        }
    }

    private var bannerBackground: some ShapeStyle {
        switch monitor.healthState {
        case .healthy: return AnyShapeStyle(AppColors.card)
        case .warning: return AnyShapeStyle(AppColors.warning.opacity(0.08))
        case .critical: return AnyShapeStyle(AppColors.danger.opacity(0.08))
        }
    }

    private var contextColor: Color {
        if monitor.contextPercent > 80 { return AppColors.danger }
        if monitor.contextPercent > 50 { return AppColors.warning }
        return AppColors.success
    }

    private var trendIcon: String {
        switch monitor.contextTrend {
        case .rising: return "arrow.up.right"
        case .stable: return "arrow.right"
        case .falling: return "arrow.down.right"
        }
    }

    private var trendColor: Color {
        switch monitor.contextTrend {
        case .rising: return AppColors.warning
        case .stable: return AppColors.muted
        case .falling: return AppColors.success
        }
    }
}
