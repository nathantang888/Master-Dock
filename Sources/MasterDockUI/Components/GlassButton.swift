import SwiftUI

public struct GlassButton: View {
    private let title: String
    private let iconSystemName: String?
    private let accentColor: Color?
    private let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    public init(
        title: String,
        iconSystemName: String? = nil,
        accentColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconSystemName = iconSystemName
        self.accentColor = accentColor
        self.action = action
    }
    
    private var buttonFillStyle: AnyShapeStyle {
        if let accent = accentColor {
            return AnyShapeStyle(accent.opacity(isHovered ? 0.90 : 0.75))
        } else if isHovered {
            return AnyShapeStyle(GlassTheme.liquidGlassHoverFill)
        } else {
            return AnyShapeStyle(GlassTheme.pillGlassFill)
        }
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = iconSystemName {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }
                Text(title)
                    .font(AppTypography.captionBold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: GlassTheme.pillRadius, style: .continuous)
                        .fill(buttonFillStyle)
                    RoundedRectangle(cornerRadius: GlassTheme.pillRadius, style: .continuous)
                        .fill(isHovered ? GlassTheme.liquidGlassHoverSheen : GlassTheme.liquidGlassSheen)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: GlassTheme.pillRadius, style: .continuous)
                    .strokeBorder(isHovered ? GlassTheme.liquidSpecularHoverBorder : GlassTheme.liquidSpecularBorder, lineWidth: 0.75)
            )
            .shadow(color: accentColor?.opacity(0.4) ?? Color.black.opacity(0.35), radius: isHovered ? 8 : 4, x: 0, y: isHovered ? 3 : 1)
            .scaleEffect(isPressed ? 0.96 : (isHovered ? 1.02 : 1.0))
        }
        .buttonStyle(.pressable)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                self.isHovered = hovering
            }
        }
    }
}

/// Circular or rounded liquid glass icon button with specular rim
public struct GlassIconButton: View {
    private let iconSystemName: String
    private let size: CGFloat
    private let iconSize: CGFloat
    private let accentColor: Color?
    private let helpText: String?
    private let action: () -> Void
    
    @State private var isHovered = false
    
    public init(
        iconSystemName: String,
        size: CGFloat = 28,
        iconSize: CGFloat = 11,
        accentColor: Color? = nil,
        helpText: String? = nil,
        action: @escaping () -> Void
    ) {
        self.iconSystemName = iconSystemName
        self.size = size
        self.iconSize = iconSize
        self.accentColor = accentColor
        self.helpText = helpText
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            Image(systemName: iconSystemName)
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundColor(accentColor ?? .white.opacity(0.92))
                .frame(width: size, height: size)
                .contentShape(Circle())
                // Real Liquid Glass circle: lensing, rim highlight, built-in hover/press response.
                .liquidGlassControl(Circle(), tint: accentColor?.opacity(0.35))
        }
        .buttonStyle(.pressable)
        .help(helpText ?? "")
    }
}

/// Frosted liquid glass pill button (matching macOS "Edit Widgets" button style)
public struct GlassPillButton: View {
    private let title: String
    private let iconSystemName: String?
    private let action: () -> Void
    
    @State private var isHovered = false
    
    public init(
        title: String,
        iconSystemName: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.iconSystemName = iconSystemName
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = iconSystemName {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(GlassTheme.accentCyan)
                }
                Text(title)
                    .font(AppTypography.captionBold)
                    .foregroundColor(.white.opacity(0.95))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .contentShape(Capsule())
            // Real Liquid Glass capsule, like Notification Center's "Edit Widgets".
            .liquidGlassControl(Capsule())
        }
        .buttonStyle(.pressable)
    }
}

public struct GlassSearchBar: View {
    @Binding public var text: String
    public var placeholder: String
    @FocusState private var isFocused: Bool
    
    public init(text: Binding<String>, placeholder: String = "Search...") {
        self._text = text
        self.placeholder = placeholder
    }
    
    private var searchFillStyle: AnyShapeStyle {
        if isFocused {
            return AnyShapeStyle(GlassTheme.liquidGlassHoverFill)
        } else {
            return AnyShapeStyle(GlassTheme.pillGlassFill)
        }
    }
    
    private var searchBorderStyle: AnyShapeStyle {
        if isFocused {
            return AnyShapeStyle(GlassTheme.activeBorder)
        } else {
            return AnyShapeStyle(GlassTheme.subtleSpecularBorder)
        }
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(isFocused ? GlassTheme.accentCyan : .white.opacity(0.70))
                .font(.system(size: 12, weight: .medium))
            
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(AppTypography.caption)
                .foregroundColor(.white)
                .focused($isFocused)
            
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.65))
                        .font(.system(size: 12))
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: GlassTheme.pillRadius, style: .continuous)
                    .fill(searchFillStyle)
                RoundedRectangle(cornerRadius: GlassTheme.pillRadius, style: .continuous)
                    .fill(GlassTheme.pillSheen)
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: GlassTheme.pillRadius, style: .continuous)
                .strokeBorder(searchBorderStyle, lineWidth: isFocused ? 1.0 : 0.75)
        )
        .shadow(color: isFocused ? GlassTheme.accentCyan.opacity(0.25) : Color.clear, radius: 6, x: 0, y: 1)
    }
}

public struct SectionHeader: View {
    public let title: String
    public let iconSystemName: String
    public var count: Int?
    public var actionTitle: String?
    public var onAction: (() -> Void)?
    @Environment(\.dockCardKind) private var cardKind
    
    public init(
        title: String,
        iconSystemName: String,
        count: Int? = nil,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.title = title
        self.iconSystemName = iconSystemName
        self.count = count
        self.actionTitle = actionTitle
        self.onAction = onAction
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconSystemName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(GlassTheme.accentCyan)
            
            // The card's main title can be renamed (double-click); other headers stay fixed.
            if let kind = cardKind, kind.defaultTitle == title {
                DockCardTitle(title, font: AppTypography.bodyBold)
            } else {
                Text(title)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(.white)
            }
            
            if let count = count {
                Text("\(count)")
                    .font(AppTypography.micro)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.14))
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 0.5)
                    )
            }
            
            Spacer()
            
            if let actionTitle = actionTitle, let onAction = onAction {
                Button(action: onAction) {
                    Text(actionTitle)
                        .font(AppTypography.captionBold)
                        .foregroundColor(GlassTheme.accentCyan)
                }
                .buttonStyle(.pressable)
            }
        }
    }
}

