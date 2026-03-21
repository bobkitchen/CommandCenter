import UserNotifications
#if os(iOS)
import UIKit
#endif

@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private var lastHealthState: OpenClawMonitor.HealthState?
    private var lastContextPercent: Double = 0
    private var contextAlertSent = false

    func requestPermission() {
        Task {
            let center = UNUserNotificationCenter.current()
            try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    func checkForAlerts(monitor: OpenClawMonitor) {
        let currentHealth = monitor.healthState
        let currentContext = monitor.contextPercent
        let settings = NotificationSettings.load()

        // Gateway state change
        if let last = lastHealthState, last != currentHealth {
            switch currentHealth {
            case .critical:
                if settings.gatewayAlerts {
                    sendNotification(
                        title: "System Alert",
                        body: monitor.healthSummary,
                        sound: .defaultCritical,
                        level: "critical"
                    )
                    HapticHelper.error()
                }
            case .warning:
                if settings.processAlerts {
                    sendNotification(
                        title: "System Warning",
                        body: monitor.healthSummary,
                        sound: .default,
                        level: "warning"
                    )
                    HapticHelper.medium()
                }
            case .healthy:
                if last == .critical {
                    sendNotification(
                        title: "System Recovered",
                        body: "All systems operational",
                        sound: .default,
                        level: "info"
                    )
                    HapticHelper.success()
                }
            }
        }

        // Context threshold alerts
        if settings.contextAlerts {
            let threshold = settings.contextThreshold
            if currentContext >= threshold && lastContextPercent < threshold && !contextAlertSent {
                sendNotification(
                    title: "Context Warning",
                    body: "Main context at \(Int(currentContext))% — consider rotating",
                    sound: .default,
                    level: "warning"
                )
                contextAlertSent = true
            } else if currentContext >= 95 && lastContextPercent < 95 {
                sendNotification(
                    title: "Context Critical",
                    body: "Main context at \(Int(currentContext))% — near exhaustion",
                    sound: .defaultCritical,
                    level: "critical"
                )
            }
        }

        // Reset alert flag when context drops below threshold
        if currentContext < (settings.contextThreshold - 5) {
            contextAlertSent = false
        }

        lastHealthState = currentHealth
        lastContextPercent = currentContext
    }

    private func sendNotification(title: String, body: String, sound: UNNotificationSound, level: String) {
        // Record in history
        AlertHistory.shared.add(title: title, body: body, level: level)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
