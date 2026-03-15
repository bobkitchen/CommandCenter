import SwiftUI

// MARK: - Glass Card Modifier

/// Applies Liquid Glass on iOS 26+ with material fallback on older versions.
struct GlassCard: ViewModifier {
    var cornerRadius: CGFloat = 20
    var tint: Color? = nil

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            if let tint {
                content
                    .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: cornerRadius))
            } else {
                content
                    .glassEffect(in: .rect(cornerRadius: cornerRadius))
            }
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(AppColors.border, lineWidth: 1)
                )
        }
    }
}

/// Interactive glass for tappable cards
struct GlassCardInteractive: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(AppColors.border, lineWidth: 1)
                )
        }
    }
}

/// Glass-styled button: uses glassProminent on iOS 26+, accent background on older.
struct GlassButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content.buttonStyle(.glassProminent)
        } else {
            content
                .foregroundStyle(.white)
                .background(AppColors.accent, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 20, tint: Color? = nil) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, tint: tint))
    }

    func glassCardInteractive(cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCardInteractive(cornerRadius: cornerRadius))
    }
}
