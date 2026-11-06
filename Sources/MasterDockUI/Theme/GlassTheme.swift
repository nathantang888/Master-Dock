import SwiftUI

public enum GlassTheme {
    /// The same smoky gray the cards show, used under every plain glass button and tab so they
    /// match the cards and each other no matter how bright the screen behind the dock is.
    public static let controlFill = Color(white: 0.22).opacity(0.82)
    // MARK: - Liquid Glass Fills
    // Apple's Notification Center cards are a flat, even material: no painted shine across the top
    // and no bright corner rim. Those extra highlights looked fine over light wallpapers but showed
    // up as gray haze and glowing edges over dark ones, so every value here is now flat and uniform.
    // On macOS 26 the cards use the real system Liquid Glass (see liquidGlassCard below); these
    // values are the fallback for older macOS and for small controls inside the cards.
    
    /// Neutral translucent fill for cards on older macOS (no color tint, no gradient)
    public static let liquidGlassFill = LinearGradient(
        colors: [Color(white: 0.11).opacity(0.62), Color(white: 0.11).opacity(0.62)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Hover: a touch lighter, still flat
    public static let liquidGlassHoverFill = LinearGradient(
        colors: [Color(white: 0.14).opacity(0.66), Color(white: 0.14).opacity(0.66)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// No top shine (Apple's glass has none)
    public static let liquidGlassSheen = LinearGradient(
        colors: [Color.clear, Color.clear],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Hover / selected: a faint even lift instead of a top shine
    public static let liquidGlassHoverSheen = LinearGradient(
        colors: [Color.white.opacity(0.05), Color.white.opacity(0.05)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Controls inside cards (search fields, chips, rows): a flat light wash like Notification Center
    public static let pillGlassFill = LinearGradient(
        colors: [Color.white.opacity(0.07), Color.white.opacity(0.07)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Hover control fill
    public static let pillGlassHoverFill = LinearGradient(
        colors: [Color.white.opacity(0.11), Color.white.opacity(0.11)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// No top shine on controls
    public static let pillSheen = LinearGradient(
        colors: [Color.clear, Color.clear],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Hover: faint even lift
    public static let pillHoverSheen = LinearGradient(
        colors: [Color.white.opacity(0.03), Color.white.opacity(0.03)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Transparent dock panel background (uncolored liquid glass)
    public static let dockPanelFill = LinearGradient(
        colors: [Color.clear, Color.clear],
        startPoint: .top,
        endPoint: .bottom
    )
    
    // MARK: - Hairline Borders
    // A single, even hairline all the way around, like Apple's cards. The old borders were up to
    // 42% white at the top-left corner, which glowed against dark backgrounds.
    
    public static let liquidSpecularBorder = LinearGradient(
        colors: [Color.white.opacity(0.10), Color.white.opacity(0.10)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    public static let liquidSpecularHoverBorder = LinearGradient(
        colors: [Color.white.opacity(0.15), Color.white.opacity(0.15)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Controls inside cards are borderless in Notification Center; keep only a barely-there edge
    public static let subtleSpecularBorder = LinearGradient(
        colors: [Color.white.opacity(0.05), Color.white.opacity(0.05)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Focus border for text fields (system accent blue, no rainbow)
    public static let activeBorder = LinearGradient(
        colors: [Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.85), Color(red: 0.04, green: 0.52, blue: 1.0).opacity(0.85)],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Outer vertical edge divider separating dock from screen
    public static let dockEdgeDivider = LinearGradient(
        colors: [Color.white.opacity(0.08), Color.white.opacity(0.08)],
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
    public static let cardRadius: CGFloat = 22.0
    public static let dockRadius: CGFloat = 24.0
    public static let pillRadius: CGFloat = 13.0
    public static let smallPillRadius: CGFloat = 8.0
    
    // MARK: - Card shadow (measured from Notification Center)
    // Over a white page, Notification Center is ~20% darker right at a card's edge and fades to
    // nothing ~60pt out (sampled: 202 at the edge, 227 at 15pt, 244 at 30pt, 255 by 60pt).
    // That is a Gaussian with ~23pt spread at ~42% strength.
    public static let cardShadowOpacity: Double = 0.42
    public static let cardShadowSpread: CGFloat = 23
    /// Space the scroll area keeps beside the cards so this shadow is never cropped.
    public static let cardShadowBleed: CGFloat = 72
    
    // MARK: - Ambient Shadows
    // Notification Center cards barely cast a shadow; heavy shadows made dark edges muddy.
    public static let ambientShadow = Color.black.opacity(0.12)
    public static let contactShadow = Color.black.opacity(0.0)
    public static let hoverShadow = Color.black.opacity(0.16)
    public static let specularGlow = Color.white.opacity(0.0)
}

public extension View {
    /// Card background. On macOS 26 this is Apple's own Liquid Glass material, so it matches
    /// Notification Center exactly over light and dark backgrounds. Older macOS gets a flat
    /// system material with an even hairline edge.
    func liquidGlassCard(cornerRadius: CGFloat = GlassTheme.cardRadius, isHovered: Bool = false) -> some View {
        self.modifier(LiquidGlassCardModifier(cornerRadius: cornerRadius, isHovered: isHovered))
    }
    
    /// Multi-layer liquid glass pill modifier for internal controls, inputs, chips, and buttons
    func liquidPillStyle(cornerRadius: CGFloat = GlassTheme.pillRadius, isHovered: Bool = false) -> some View {
        self
            .background(
                ZStack {
                    // 1. Translucent Glass Chip Fill (allows card transparency to shine through)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isHovered ? GlassTheme.pillGlassHoverFill : GlassTheme.pillGlassFill)
                    
                    // 2. Delicate Top Sheen
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isHovered ? GlassTheme.pillHoverSheen : GlassTheme.pillSheen)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(GlassTheme.subtleSpecularBorder, lineWidth: 0.5)
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


/// Applies the system Liquid Glass material to a card, with a fallback for older macOS.
struct LiquidGlassCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let isHovered: Bool
    
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        if reduceTransparency || contrast == .increased {
            // Accessibility: a frosted, near-solid card instead of see-through glass, with a
            // clearly visible edge when Increase Contrast is on.
            content
                .background(shape.fill(Color(white: isHovered ? 0.17 : 0.14).opacity(0.97)))
                .overlay(shape.strokeBorder(Color.white.opacity(contrast == .increased ? 0.38 : 0.12), lineWidth: contrast == .increased ? 1.0 : 0.5))
                .clipShape(shape)
        } else if #available(macOS 26.0, *) {
            content
                // Hover: a faint even lift, no shine
                .background(shape.fill(Color.white.opacity(isHovered ? 0.04 : 0.0)))
                .glassEffect(.regular, in: shape)
                .background(cardShadow(shape))
        } else {
            content
                .background(
                    ZStack {
                        VisualEffectBlur(material: .popover, blendingMode: .behindWindow, state: .active)
                        shape.fill(isHovered ? GlassTheme.liquidGlassHoverFill : GlassTheme.liquidGlassFill)
                    }
                    .clipShape(shape)
                )
                .overlay(
                    shape.strokeBorder(isHovered ? GlassTheme.liquidSpecularHoverBorder : GlassTheme.liquidSpecularBorder, lineWidth: 0.5)
                )
                .clipShape(shape)
                .background(cardShadow(shape))
        }
    }
    
    /// Wide, soft shadow matched to Notification Center (see GlassTheme.cardShadow*).
    /// The card's own area is cut out of the shadow, so nothing dark sits BEHIND the glass:
    /// Liquid Glass bends and colors itself from what is behind it, and a dark slab there made
    /// the cards look like flat gray pods instead of glass.
    private func cardShadow(_ shape: RoundedRectangle) -> some View {
        shape
            .fill(Color.black.opacity(GlassTheme.cardShadowOpacity))
            .blur(radius: GlassTheme.cardShadowSpread)
            .mask(
                Rectangle()
                    .padding(-GlassTheme.cardShadowBleed)
                    .overlay(shape.blendMode(.destinationOut))
                    .compositingGroup()
            )
            .allowsHitTesting(false)
    }
}

// MARK: - Press feedback

/// Apple-style press feedback: the control reacts the instant it is pressed (not on release)
/// with a small, quick squeeze, and springs back when let go. Otherwise looks like `.plain`.
public struct PressableButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init() {}
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.82 : 1.0)
            .animation(
                configuration.isPressed
                    ? .easeOut(duration: 0.08)
                    : .spring(response: 0.3, dampingFraction: 1.0),
                value: configuration.isPressed
            )
    }
}

public extension ButtonStyle where Self == PressableButtonStyle {
    /// Plain-looking button with instant press feedback.
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
}


// MARK: - Liquid Glass controls

public extension View {
    /// Real system Liquid Glass for floating controls (buttons, pills, chips), with Apple's built-in
    /// lensing, rim highlight and interactive press/hover response. `tint` marks a selected or
    /// primary control. Falls back to a frosted look on older macOS and with Reduce Transparency.
    func liquidGlassControl<S: Shape>(_ shape: S, tint: Color? = nil, interactive: Bool = true) -> some View {
        modifier(LiquidGlassControlModifier(shape: shape, tint: tint, interactive: interactive))
    }
}

struct LiquidGlassControlModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool
    
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    
    func body(content: Content) -> some View {
        if reduceTransparency || contrast == .increased {
            content
                .background(shape.fill(tint?.opacity(0.9) ?? Color(white: 0.2)))
                .overlay(shape.stroke(Color.white.opacity(contrast == .increased ? 0.4 : 0.12), lineWidth: contrast == .increased ? 1 : 0.5))
        } else if #available(macOS 26.0, *) {
            // Liquid Glass brightens to match whatever is behind it, so over a white web page
            // plain glass turned white while the same button over a dark area stayed dark.
            // A light dark layer on top keeps every control the same smoky glass everywhere.
            content
                .background(shape.fill(tint == nil ? GlassTheme.controlFill : Color.clear))
                .glassEffect(makeGlass(), in: shape)
        } else {
            content
                .background(
                    ZStack {
                        VisualEffectBlur(material: .hudWindow, blendingMode: .behindWindow, state: .active)
                        shape.fill(tint?.opacity(0.75) ?? Color.white.opacity(0.06))
                    }
                    .clipShape(shape)
                )
                .overlay(shape.stroke(Color.white.opacity(0.12), lineWidth: 0.5))
        }
    }
    
    @available(macOS 26.0, *)
    private func makeGlass() -> Glass {
        var glass = Glass.regular
        if let tint = tint { glass = glass.tint(tint) }
        // Not using .interactive(): in the dock's floating panel its light-up effect can stay
        // stuck on after a click, leaving buttons bright white. Press feedback comes from
        // the .pressable button style instead, so every control keeps the same glass look.
        _ = interactive
        return glass
    }
}

/// Groups nearby Liquid Glass elements so they share lighting and render as one system, as Apple
/// recommends. A small spacing keeps separate pieces from melting into each other.
public struct GlassGroup<Content: View>: View {
    private let spacing: CGFloat
    private let content: Content
    
    public init(spacing: CGFloat = 4, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }
    
    public var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
