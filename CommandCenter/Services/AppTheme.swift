import SwiftUI

enum ThemeMode: String, CaseIterable, Sendable {
    case dark = "Dark"
    case oled = "OLED"
}

/// Theme state stored in UserDefaults. Uses nonisolated(unsafe) for the singleton
/// so AppColors can read it from any context (all callers are views on @MainActor).
final class AppTheme: @unchecked Sendable {
    static let shared = AppTheme()

    var mode: ThemeMode {
        get { ThemeMode(rawValue: UserDefaults.standard.string(forKey: "appTheme") ?? "dark") ?? .dark }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "appTheme") }
    }

    var background: Color {
        mode == .oled ? .black : Color(hex: 0x0d1117)
    }
    var backgroundAlt: Color {
        mode == .oled ? Color(hex: 0x0a0a0a) : Color(hex: 0x1a1f2e)
    }
    var card: Color {
        mode == .oled ? Color(hex: 0x0c0c0c) : Color(hex: 0x161b22)
    }
    var border: Color {
        mode == .oled ? Color(hex: 0x1a1a1a) : Color(hex: 0x30363d)
    }
}
