#if os(iOS)
import SwiftUI

@main
struct CommandCenterApp: App {
    @State private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                ContentView()
                    .environment(authService)
            } else {
                LoginView()
                    .environment(authService)
            }
        }
    }
}
#endif
