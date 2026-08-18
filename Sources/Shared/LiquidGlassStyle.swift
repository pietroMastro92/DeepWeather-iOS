import SwiftUI

// MARK: - Liquid Glass Design System

/// Modern Apple-grade Liquid Glass & Frosted Material design system for SwiftUI.
/// Combines optical ultra-thin materials, specular gradient borders, ambient depth shadows, and interactive spring physics.
public struct LiquidGlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    var materialOpacity: Double = 0.85
    var strokeAlpha: Double = 0.35
    var shadowRadius: CGFloat = 12
    var shadowOpacity: Double = 0.15

    public func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial.opacity(materialOpacity))
            }
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(strokeAlpha),
                                .white.opacity(strokeAlpha * 0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .shadow(
                color: Color.black.opacity(shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius * 0.4
            )
    }
}

public struct LiquidGlassCapsuleModifier: ViewModifier {
    var materialOpacity: Double = 0.85
    var strokeAlpha: Double = 0.45
    var shadowRadius: CGFloat = 10
    var shadowOpacity: Double = 0.20

    public func body(content: Content) -> some View {
        content
            .background {
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial.opacity(materialOpacity))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(strokeAlpha),
                                .white.opacity(strokeAlpha * 0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .shadow(
                color: Color.black.opacity(shadowOpacity),
                radius: shadowRadius,
                x: 0,
                y: shadowRadius * 0.4
            )
    }
}

public struct LiquidGlassCircleModifier: ViewModifier {
    var materialOpacity: Double = 0.85
    var strokeAlpha: Double = 0.40
    var shadowRadius: CGFloat = 8

    public func body(content: Content) -> some View {
        content
            .background {
                Circle()
                    .fill(.ultraThinMaterial.opacity(materialOpacity))
            }
            .overlay {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(strokeAlpha),
                                .white.opacity(strokeAlpha * 0.25)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.8
                    )
            }
            .shadow(color: Color.black.opacity(0.18), radius: shadowRadius, x: 0, y: 3)
    }
}

// MARK: - View Extensions

public extension View {
    /// Applies an authentic Apple Frosted Liquid Glass card style.
    func liquidGlassCard(
        cornerRadius: CGFloat = 16,
        materialOpacity: Double = 0.85,
        strokeAlpha: Double = 0.35,
        shadowRadius: CGFloat = 12,
        shadowOpacity: Double = 0.15
    ) -> some View {
        modifier(
            LiquidGlassCardModifier(
                cornerRadius: cornerRadius,
                materialOpacity: materialOpacity,
                strokeAlpha: strokeAlpha,
                shadowRadius: shadowRadius,
                shadowOpacity: shadowOpacity
            )
        )
    }

    /// Applies an authentic Apple Frosted Liquid Glass capsule/pill style.
    func liquidGlassCapsule(
        materialOpacity: Double = 0.85,
        strokeAlpha: Double = 0.45,
        shadowRadius: CGFloat = 10,
        shadowOpacity: Double = 0.20
    ) -> some View {
        modifier(
            LiquidGlassCapsuleModifier(
                materialOpacity: materialOpacity,
                strokeAlpha: strokeAlpha,
                shadowRadius: shadowRadius,
                shadowOpacity: shadowOpacity
            )
        )
    }

    /// Applies an authentic Apple Frosted Liquid Glass circular style.
    func liquidGlassCircle(
        materialOpacity: Double = 0.85,
        strokeAlpha: Double = 0.40,
        shadowRadius: CGFloat = 8
    ) -> some View {
        modifier(
            LiquidGlassCircleModifier(
                materialOpacity: materialOpacity,
                strokeAlpha: strokeAlpha,
                shadowRadius: shadowRadius
            )
        )
    }
}
