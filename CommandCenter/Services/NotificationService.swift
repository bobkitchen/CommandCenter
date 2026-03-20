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

    /// Called each time the monitor refreshes. Compares previous vs current state.
    func checkForAlerts(monitor: OpenClawMonitor) {
        let currentHealth = monitor.healthState
        let currentContext = monitor.contextPercent

        // Gateway state change
        if let last = lastHealthState, last != currentHealth {
            switch currentHealth {
            case .critical:
                sendNotification(
                    title: "System Alert",
                    body: monitor.healthSummary,
                    sound: .defaultCritical
                )
                HapticHelper.error()
            case .warning:
                sendNotification(
                    title: "System Warning",
                    body: monitor.healthSummary,
                    sound: .default
                )
                HapticHelper.medium()
            case .healthy:
                if last == .critical {
                    sendNotification(
                        title: "System Recovered",
                        body: "All systems operational",
                        sound: .default
                    )
                    HapticHelper.success()
                }
            }
        }

        // Context threshold alerts (85% and 95%)
        if currentContext >= 85 && lastContextPercent < 85 && !contextAlertSent {
            sendNotification(
                title: "Context Warning",
                body: "Main context at \(Int(currentContext))% — consider rotating",
                sound: .default
            )
            contextAlertSent = true
        } else if currentContext >= 95 && lastContextPercent < 95 {
            sendNotification(
                title: "Context Critical",
                body: "Main context at \(Int(currentContext))% — near exhaustion",
                sound: .defaultCritical
            )
        }

        // Reset alert flag when context drops
        if currentContext < 80 {
            contextAlertSent = false
        }

        lastHealthState = currentHealth
        lastContextPercent = currentContext
    }

    private func sendNotification(title: String, body: String, sound: UNNotificationSound) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )
        UNUserNotificationCenter.current().add(request)
    }
}
