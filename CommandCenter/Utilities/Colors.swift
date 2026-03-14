import SwiftUI

enum AppColors {
    static let background   = Color(hex: 0x0d1117)
    static let backgroundAlt = Color(hex: 0x1a1f2e)
    static let card         = Color(hex: 0x161b22)
    static let border       = Color(hex: 0x30363d)
    static let accent       = Color(hex: 0x58a6ff)
    static let text         = Color(hex: 0xe6edf3)
    static let muted        = Color(hex: 0x8b949e)
    static let success      = Color(hex: 0x3fb950)
    static let warning      = Color(hex: 0xd29922)
    static let danger       = Color(hex: 0xf85149)

    /// Rich gradient background to give glass something to refract
    static var backgroundGradient: some View {
        LinearGradient(
            colors: [background, backgroundAlt, background],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
