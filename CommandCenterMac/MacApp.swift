import SwiftUI

#if os(macOS)
@main
struct CommandCenterMacApp: App {
    @State private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            if authService.isAuthenticated {
                MacContentView()
                    .environment(authService)
            } else {
                LoginView()
                    .frame(width: 400, height: 500)
                    .environment(authService)
            }
        }
        .defaultSize(width: 1200, height: 800)
    }
}
#endif
