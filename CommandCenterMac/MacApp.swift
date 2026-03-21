import SwiftUI

#if os(macOS)
@main
struct CommandCenterMacApp: App {
    @State private var authService = AuthService()
    @State private var monitor = OpenClawMonitor()

    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                MacContentView()
                    .environment(authService)
                    .task { monitor.startMonitoring() }
            } else {
                LoginView()
                    .frame(width: 400, height: 500)
                    .environment(authService)
            }
        }
        .defaultSize(width: 1200, height: 800)

        MenuBarExtra {
            MenuBarExtraView(monitor: monitor)
        } label: {
            Image(systemName: monitor.healthState == .healthy ? "circle.fill" : "exclamationmark.circle.fill")
                .symbolRenderingMode(.palette)
                .foregroundStyle(monitor.healthState == .healthy ? .green : (monitor.healthState == .warning ? .yellow : .red))
        }
        .menuBarExtraStyle(.window)
    }
}
#endif
