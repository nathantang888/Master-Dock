import SwiftUI
import UniformTypeIdentifiers

/// Wraps a dock card. In edit mode it shows move and hide controls, and the card can be dragged
/// onto another card to reorder.
struct EditableDockCard<Content: View>: View {
    let kind: DockWidgetKind
    @ObservedObject var layout: DockLayoutStore
    let content: Content

    @State private var isDropTarget = false

    init(kind: DockWidgetKind, layout: DockLayoutStore, @ViewBuilder content: () -> Content) {
        self.kind = kind
        self.layout = layout
        self.content = content()
    }

    private var visible: [DockWidgetConfig] { layout.visibleWidgets }
    private var isFirst: Bool { visible.first?.kind == kind }
    private var isLast: Bool { visible.last?.kind == kind }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // In edit mode the controls get their own row above the card, so they never cover its content.
            if layout.isEditing {
                HStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .help("Drag the card to reorder")
                    Text(layout.title(for: kind) ?? kind.catalogName)
                        .font(AppTypography.captionBold)
                        .foregroundColor(.white.opacity(0.75))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    control("chevron.up", help: "Move up", disabled: isFirst) { layout.move(kind, by: -1) }
                    control("chevron.down", help: "Move down", disabled: isLast) { layout.move(kind, by: 1) }
                    control("eye.slash", help: "Hide this widget") { layout.setVisible(kind, false) }
                }
                .padding(.horizontal, 6)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            content
            .overlay {
                if layout.isEditing {
                    RoundedRectangle(cornerRadius: GlassTheme.cardRadius, style: .continuous)
                        .strokeBorder(isDropTarget ? GlassTheme.accentBlue : Color.white.opacity(0.22),
                                      style: StrokeStyle(lineWidth: isDropTarget ? 2 : 1, dash: isDropTarget ? [] : [5, 4]))
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(layout.isEditing ? 0.985 : 1)
        }
            .draggable(kind.rawValue) {
                Label(layout.title(for: kind) ?? kind.catalogName, systemImage: kind.iconName)
                    .padding(8)
                    .background(Capsule().fill(.ultraThinMaterial))
            }
            .dropDestination(for: String.self) { items, _ in
                guard layout.isEditing, let raw = items.first, let dragged = DockWidgetKind(rawValue: raw), dragged != kind else { return false }
                withAnimation(.spring(response: 0.35, dampingFraction: 1)) { layout.move(dragged, before: kind) }
                return true
            } isTargeted: { targeted in
                withAnimation(.easeOut(duration: 0.12)) { isDropTarget = targeted && layout.isEditing }
            }
            .animation(.spring(response: 0.35, dampingFraction: 1), value: layout.isEditing)
    }

    private func control(_ icon: String, help: String, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(.spring(response: 0.35, dampingFraction: 1)) { action() } }) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white.opacity(disabled ? 0.3 : 0.95))
                .frame(width: 26, height: 22)
                .background(Capsule().fill(Color.white.opacity(0.12)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
                .contentShape(Capsule())
        }
        .buttonStyle(.pressable)
        .disabled(disabled)
        .help(help)
    }
}

/// Shown at the bottom of the dock in edit mode: hidden widgets you can add back.
struct HiddenWidgetsPanel: View {
    @ObservedObject var layout: DockLayoutStore

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Add Widgets")
                    .font(AppTypography.titleMedium)
                    .foregroundColor(.white)
                Spacer()
                Button("Reset Layout") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 1)) { layout.resetToDefault() }
                }
                .buttonStyle(.pressable)
                .font(AppTypography.captionBold)
                .foregroundColor(.white.opacity(0.7))
            }
            Text("Drag cards to reorder, or use the arrows. Double-click any card title to rename it.")
                .font(AppTypography.caption)
                .foregroundColor(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)

            if layout.hiddenWidgets.isEmpty {
                Text("Every widget is already on your dock.")
                    .font(AppTypography.caption)
                    .foregroundColor(.white.opacity(0.55))
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 6) {
                    ForEach(layout.hiddenWidgets) { config in
                        Button(action: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 1)) { layout.setVisible(config.kind, true) }
                        }) {
                            HStack(spacing: 10) {
                                Image(systemName: config.kind.iconName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(GlassTheme.accentCyan)
                                    .frame(width: 28, height: 28)
                                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.white.opacity(0.10)))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(config.customTitle ?? config.kind.catalogName)
                                        .font(AppTypography.bodyBold)
                                        .foregroundColor(.white)
                                    Text(config.kind.summary)
                                        .font(AppTypography.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(GlassTheme.accentBlue)
                            }
                            .padding(8)
                            .contentShape(Rectangle())
                            .liquidPillStyle(cornerRadius: 12)
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }
        }
    }
}
