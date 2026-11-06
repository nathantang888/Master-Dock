import SwiftUI
import MasterDockCore
import MasterDockServices

public struct ClipboardSectionView: View {
    @ObservedObject public var clipboardService: ClipboardMonitorService
    @State private var searchText = ""
    @State private var selectedFilter: ClipboardFilter = .all
    @State private var copiedItemID: UUID? = nil

    public enum ClipboardFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case pinned = "Pinned"
        case text = "Text"
        case links = "Links"
        case code = "Code"
        case images = "Images"

        public var id: String { rawValue }
    }

    public init(clipboardService: ClipboardMonitorService) {
        self.clipboardService = clipboardService
    }

    private var filteredItems: [ClipboardItem] {
        clipboardService.items.filter { item in
            let matchesFilter: Bool
            switch selectedFilter {
            case .all: matchesFilter = true
            case .pinned: matchesFilter = item.isPinned
            case .text: matchesFilter = item.type == .text
            case .images: matchesFilter = item.type == .image
            case .links: matchesFilter = item.type == .url
            case .code: matchesFilter = item.type == .code
            }
            guard matchesFilter else { return false }
            guard !searchText.isEmpty else { return true }
            return (item.textContent?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                item.previewTitle.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var unpinnedCount: Int { clipboardService.items.filter { !$0.isPinned }.count }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                title: "Clipboard History",
                iconSystemName: "doc.on.clipboard.fill",
                count: clipboardService.items.count,
                // "Clear" only removes unpinned items, so pinned prompts stay ready to use.
                actionTitle: unpinnedCount == 0 ? nil : "Clear",
                onAction: { clipboardService.clearHistory() }
            )

            if !clipboardService.hasAnsweredPrivacyPrompt {
                ClipboardPrivacyPrompt(
                    onEnable: { withAnimation(.spring(response: 0.3, dampingFraction: 1)) { clipboardService.enableHistory() } },
                    onDecline: { withAnimation(.spring(response: 0.3, dampingFraction: 1)) { clipboardService.declineHistory() } }
                )
            } else if !clipboardService.isHistoryEnabled {
                HStack(spacing: 8) {
                    Image(systemName: "pause.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                    Text("Clipboard history is off.")
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.75))
                    Spacer()
                    Button("Turn On") { clipboardService.enableHistory() }
                        .buttonStyle(.pressable)
                        .font(AppTypography.captionBold)
                        .foregroundColor(GlassTheme.accentCyan)
                }
                .padding(10)
                .liquidPillStyle(cornerRadius: 12)
            }

            GlassSearchBar(text: $searchText, placeholder: "Search copied text, images, links...")

            // Category filter pills (scrolls sideways on narrow docks)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(ClipboardFilter.allCases) { filter in
                        Button(action: { selectedFilter = filter }) {
                            HStack(spacing: 3) {
                                if filter == .pinned {
                                    Image(systemName: "pin.fill").font(.system(size: 8, weight: .bold))
                                }
                                Text(filter.rawValue)
                            }
                            .font(AppTypography.captionBold)
                            .foregroundColor(selectedFilter == filter ? .white : .white.opacity(0.80))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter ? AnyShapeStyle(GlassTheme.accentBlue.opacity(0.85)) : AnyShapeStyle(GlassTheme.pillGlassFill))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(selectedFilter == filter ? AnyShapeStyle(Color.white.opacity(0.12)) : AnyShapeStyle(GlassTheme.subtleSpecularBorder), lineWidth: 0.8)
                            )
                        }
                        .buttonStyle(.pressable)
                    }
                }
            }

            if filteredItems.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: selectedFilter == .pinned ? "pin" : "clipboard")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.45))
                        Text(emptyMessage)
                            .font(AppTypography.caption)
                            .foregroundColor(.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredItems) { item in
                            ClipboardItemRow(
                                item: item,
                                isRecentlyCopied: copiedItemID == item.id,
                                onCopy: { copy(item) },
                                onTogglePin: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 1)) {
                                        clipboardService.togglePin(item.id)
                                    }
                                },
                                onDelete: {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 1)) {
                                        clipboardService.removeItem(item.id)
                                    }
                                }
                            )
                            .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }
                    }
                    .padding(.vertical, 4)
                    .background(
                        ScrollEdgeFadeObserver(fadeLength: 20.0, fadeThreshold: 14.0)
                    )
                }
                .frame(maxHeight: 220)
            }
        }
    }

    private var emptyMessage: String {
        if !searchText.isEmpty { return "No matching items" }
        if selectedFilter == .pinned { return "Pin a copied item to keep it here.\nPinned items stay when you clear." }
        return "No items in clipboard history"
    }

    private func copy(_ item: ClipboardItem) {
        clipboardService.copyItemToPasteboard(item)
        withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
            copiedItemID = item.id
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            if copiedItemID == item.id {
                withAnimation(.easeOut(duration: 0.2)) { copiedItemID = nil }
            }
        }
    }
}

/// Asks before any clipboard history is saved, and explains exactly what is kept.
private struct ClipboardPrivacyPrompt: View {
    let onEnable: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(GlassTheme.accentCyan)
                Text("Turn on clipboard history?")
                    .font(AppTypography.bodyBold)
                    .foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                bullet("Saves the text, links and images you copy, only on this Mac.")
                bullet("Skips passwords and codes from password managers.")
                bullet("Delete any item, pin favorites, or turn it off anytime in Settings.")
            }
            HStack(spacing: 8) {
                Spacer()
                Button("Not Now", action: onDecline)
                    .buttonStyle(.pressable)
                    .font(AppTypography.captionBold)
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                Button(action: onEnable) {
                    Text("Turn On")
                        .font(AppTypography.captionBold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(GlassTheme.accentBlue))
                }
                .buttonStyle(.pressable)
            }
        }
        .padding(12)
        .liquidPillStyle(cornerRadius: 14)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•").foregroundColor(.white.opacity(0.6))
            Text(text)
                .font(AppTypography.caption)
                .foregroundColor(.white.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isRecentlyCopied: Bool
    let onCopy: () -> Void
    let onTogglePin: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onCopy) {
                HStack(spacing: 10) {
                    thumbnail
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            if item.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(GlassTheme.accentCyan)
                            }
                            Text(item.previewTitle)
                                .font(AppTypography.bodyBold)
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }
                        Text(isRecentlyCopied ? "Copied" : item.previewSubtitle)
                            .font(AppTypography.caption)
                            .foregroundColor(isRecentlyCopied ? GlassTheme.accentEmerald : .white.opacity(0.70))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable)
            .help("Click to copy")

            // Row actions: always show the pin on pinned items, everything else on hover.
            HStack(spacing: 2) {
                if isHovered || item.isPinned {
                    rowButton(item.isPinned ? "pin.fill" : "pin",
                              color: item.isPinned ? GlassTheme.accentCyan : .white.opacity(0.75),
                              help: item.isPinned ? "Unpin" : "Pin (keeps it when you clear)",
                              action: onTogglePin)
                }
                if isHovered {
                    rowButton("xmark", color: .white.opacity(0.75), help: "Delete this item", action: onDelete)
                }
            }
            .transition(.opacity)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .liquidPillStyle(cornerRadius: 12, isHovered: isHovered)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(isRecentlyCopied ? AnyShapeStyle(GlassTheme.accentEmerald.opacity(0.8)) : AnyShapeStyle(Color.clear), lineWidth: 0.8)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if item.type == .image, let data = item.imageData, let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 34, height: 34)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: iconName(for: item.type))
                    .font(.system(size: 14))
                    .foregroundColor(GlassTheme.accentCyan)
            }
        }
    }

    private func rowButton(_ icon: String, color: Color, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.white.opacity(isHovered ? 0.08 : 0)))
                .contentShape(Circle())
        }
        .buttonStyle(.pressable)
        .help(help)
    }

    private func iconName(for type: ClipboardContentType) -> String {
        switch type {
        case .text: return "text.alignleft"
        case .image: return "photo.fill"
        case .url: return "link"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .color: return "paintpalette.fill"
        }
    }
}
