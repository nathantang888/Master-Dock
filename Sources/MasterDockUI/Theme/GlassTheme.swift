import SwiftUI

public enum GlassTheme {
    // MARK: - Liquid Glass Morphism Fills (Matching macOS Notification Center & Control Center)
    
    /// Translucent liquid glass fill for main cards (translucent liquid glass allowing background colors to shine through)
    public static let liquidGlassFill = LinearGradient(
        stops: [
            .init(color: Color(red: 0.15, green: 0.15, blue: 0.17).opacity(0.68), location: 0.0),
            .init(color: Color(red: 0.09, green: 0.09, blue: 0.11).opacity(0.74), location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Brightened liquid glass fill on hover
    public static let liquidGlassHoverFill = LinearGradient(
        stops: [
            .init(color: Color(red: 0.20, green: 0.20, blue: 0.23).opacity(0.75), location: 0.0),
            .init(color: Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.80), location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Top specular sheen reflection simulating 3D light reflection across curved glass
    public static let liquidGlassSheen = LinearGradient(
        stops: [
            .init(color: Color.white.opacity(0.18), location: 0.0),
            .init(color: Color.white.opacity(0.06), location: 0.22),
            .init(color: Color.clear, location: 0.60)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Enhanced top sheen on hover
    public static let liquidGlassHoverSheen = LinearGradient(
        stops: [
            .init(color: Color.white.opacity(0.26), location: 0.0),
            .init(color: Color.white.opacity(0.08), location: 0.30),
            .init(color: Color.clear, location: 0.75)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Translucent pill / control glass fill
    public static let pillGlassFill = LinearGradient(
        stops: [
            .init(color: Color.white.opacity(0.12), location: 0.0),
            .init(color: Color.white.opacity(0.06), location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Hover pill glass fill
    public static let pillGlassHoverFill = LinearGradient(
        stops: [
            .init(color: Color.white.opacity(0.22), location: 0.0),
            .init(color: Color.white.opacity(0.12), location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Transparent dock panel background (uncolored liquid glass)
    public static let dockPanelFill = LinearGradient(
        stops: [
            .init(color: Color.clear, location: 0.0),
            .init(color: Color.clear, location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - Specular Rim Bevels (Precision Light Refraction Borders)
    
    /// 3D specular highlight border for primary liquid glass cards (continuous perimeter outline)
    public static let liquidSpecularBorder = LinearGradient(
        stops: [
            .init(color: Color.white.opacity(0.40), location: 0.0),
            .init(color: Color.white.opacity(0.22), location: 0.28),
            .init(color: Color.white.opacity(0.12), location: 0.70),
            .init(color: Color.white.opacity(0.24), location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Brightened specular highlight on hover
    public static let liquidSpecularHoverBorder = LinearGradient(
        stops: [
            .init(color: Color.white.opacity(0.60), location: 0.0),
            .init(color: Color.white.opacity(0.32), location: 0.30),
            .init(color: Color.white.opacity(0.18), location: 0.70),
            .init(color: Color.white.opacity(0.38), location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Subtle specular rim for inner pills, tags, and inputs
    public static let subtleSpecularBorder = LinearGradient(
        stops: [
            .init(color: Color.white.opacity(0.26), location: 0.0),
            .init(color: Color.white.opacity(0.15), location: 0.35),
            .init(color: Color.white.opacity(0.08), location: 0.75),
            .init(color: Color.white.opacity(0.18), location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Glowing active focus border
    public static let activeBorder = LinearGradient(
        stops: [
            .init(color: Color.white.opacity(0.70), location: 0.0),
            .init(color: Color(red: 0.35, green: 0.75, blue: 1.0), location: 0.4),
            .init(color: Color(red: 0.65, green: 0.45, blue: 1.0), location: 1.0)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// Outer vertical edge divider separating dock from screen
    public static let dockEdgeDivider = LinearGradient(
        stops: [
            .init(color: Color.white.opacity(0.30), location: 0.0),
            .init(color: Color.white.opacity(0.14), location: 0.25),
            .init(color: Color.white.opacity(0.08), location: 0.70),
            .init(color: Color.white.opacity(0.20), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // MARK: - Vibrant Accents
    public static let accentBlue = Color(red: 0.0, green: 0.50, blue: 1.0)
    public static let accentCyan = Color(red: 0.25, green: 0.85, blue: 1.0)
    public static let accentPurple = Color(red: 0.70, green: 0.35, blue: 0.90)
    public static let accentEmerald = Color(red: 0.20, green: 0.82, blue: 0.40)
    public static let accentAmber = Color(red: 1.0, green: 0.60, blue: 0.0)
    public static let accentRose = Color(red: 1.0, green: 0.22, blue: 0.38)
    
    // MARK: - Curvature & Radii (Superellipse)
    public static let cardRadius: CGFloat = 20.0
    public static let dockRadius: CGFloat = 24.0
    public static let pillRadius: CGFloat = 13.0
    public static let smallPillRadius: CGFloat = 8.0
    
    // MARK: - Ambient Shadows
    public static let ambientShadow = Color.black.opacity(0.40)
    public static let contactShadow = Color.black.opacity(0.20)
    public static let hoverShadow = Color.black.opacity(0.52)
    public static let specularGlow = Color.white.opacity(0.14)
}

public extension View {
    /// Multi-layer liquid glass card modifier with vibrancy, dark tint, top sheen, 3D specular rim, and ambient drop shadows
    func liquidGlassCard(cornerRadius: CGFloat = GlassTheme.cardRadius, isHovered: Bool = false) -> some View {
        self
            .background(
                ZStack {
                    // 1. Native Frosted Vibrancy Blur (thinMaterial lets background colors shine through translucent glass)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.thinMaterial)
                    
                    // 2. Translucent Liquid Glass Tint Gradient
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isHovered ? GlassTheme.liquidGlassHoverFill : GlassTheme.liquidGlassFill)
                    
                    // 3. Specular Top Sheen (Simulating light hitting curved top)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isHovered ? GlassTheme.liquidGlassHoverSheen : GlassTheme.liquidGlassSheen)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(isHovered ? GlassTheme.liquidSpecularHoverBorder : GlassTheme.liquidSpecularBorder, lineWidth: 0.85)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: isHovered ? GlassTheme.hoverShadow : GlassTheme.ambientShadow, radius: isHovered ? 15 : 10, x: 0, y: isHovered ? 6 : 4)
            .shadow(color: GlassTheme.contactShadow, radius: 2, x: 0, y: 1)
    }
    
    /// Multi-layer liquid glass pill modifier for internal controls, inputs, chips, and buttons
    func liquidPillStyle(cornerRadius: CGFloat = GlassTheme.pillRadius, isHovered: Bool = false) -> some View {
        self
            .background(
                ZStack {
                    // 1. Native Vibrancy Material
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.thinMaterial)
                    
                    // 2. Translucent Glass Fill
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isHovered ? GlassTheme.pillGlassHoverFill : GlassTheme.pillGlassFill)
                    
                    // 3. Delicate Top Sheen
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isHovered ? GlassTheme.liquidGlassHoverSheen : GlassTheme.liquidGlassSheen)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(isHovered ? GlassTheme.liquidSpecularHoverBorder : GlassTheme.subtleSpecularBorder, lineWidth: 0.75)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }
    
    /// Liquid glass panel background for the entire dock container matching macOS Notification Center
    func liquidPanelBackground() -> some View {
        self
            .background(Color.clear)
    }
    
    /// Vibrant accent glow modifier
    func vibrantGlow(color: Color = GlassTheme.accentCyan, radius: CGFloat = 8) -> some View {
        self.shadow(color: color.opacity(0.55), radius: radius, x: 0, y: 0)
    }
}

