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
        case text = "Text"
        case images = "Images"
        case links = "Links"
        case code = "Code"
        
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
            case .text: matchesFilter = item.type == .text
            case .images: matchesFilter = item.type == .image
            case .links: matchesFilter = item.type == .url
            case .code: matchesFilter = item.type == .code
            }
            
            if !searchText.isEmpty {
                let matchesSearch = (item.textContent?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                                    item.previewTitle.localizedCaseInsensitiveContains(searchText)
                return matchesFilter && matchesSearch
            }
            return matchesFilter
        }
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                title: "Clipboard History",
                iconSystemName: "doc.on.clipboard.fill",
                count: clipboardService.items.count,
                actionTitle: clipboardService.items.isEmpty ? nil : "Clear",
                onAction: { clipboardService.clearHistory() }
            )
            
            // Search Bar
            GlassSearchBar(text: $searchText, placeholder: "Search copied text, images, links...")
            
            // Category Filter Pills
            HStack(spacing: 6) {
                ForEach(ClipboardFilter.allCases) { filter in
                    Button(action: { selectedFilter = filter }) {
                        Text(filter.rawValue)
                            .font(AppTypography.captionBold)
                            .foregroundColor(selectedFilter == filter ? .white : .white.opacity(0.80))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter ? AnyShapeStyle(GlassTheme.accentBlue.opacity(0.9)) : AnyShapeStyle(Color(red: 0.20, green: 0.20, blue: 0.23).opacity(0.75)))
                            )
                            .overlay(
                                Capsule()
                                    .strokeBorder(selectedFilter == filter ? AnyShapeStyle(Color.white.opacity(0.5)) : AnyShapeStyle(GlassTheme.subtleSpecularBorder), lineWidth: 0.8)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Item List
            if filteredItems.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "clipboard")
                            .font(.system(size: 22))
                            .foregroundColor(.white.opacity(0.45))
                        Text(searchText.isEmpty ? "No items in clipboard history" : "No matching items")
                            .font(AppTypography.caption)
                            .foregroundColor(.white.opacity(0.65))
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
                                isRecentlyCopied: copiedItemID == item.id
                            ) {
                                clipboardService.copyItemToPasteboard(item)
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                    copiedItemID = item.id
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                    if copiedItemID == item.id {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            copiedItemID = nil
                                        }
                                    }
                                }
                            }
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
}

private struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isRecentlyCopied: Bool
    let onClick: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onClick) {
            HStack(spacing: 10) {
                // Icon / Thumbnail
                Group {
                    if item.type == .image, let data = item.imageData, let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 34, height: 34)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.white.opacity(0.12))
                                .frame(width: 34, height: 34)
                            Image(systemName: iconName(for: item.type))
                                .font(.system(size: 14))
                                .foregroundColor(GlassTheme.accentCyan)
                        }
                    }
                }
                
                // Text Details
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.previewTitle)
                        .font(AppTypography.bodyBold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(item.previewSubtitle)
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.70))
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Copy Status Indicator
                ZStack {
                    if isRecentlyCopied {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(GlassTheme.accentEmerald)
                            Text("Copied")
                                .font(AppTypography.micro)
                                .foregroundColor(GlassTheme.accentEmerald)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(GlassTheme.accentEmerald.opacity(0.22))
                        )
                        .transition(.scale.combined(with: .opacity))
                    } else {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundColor(isHovered ? .white : .white.opacity(0.55))
                            .padding(6)
                            .background(
                                Circle()
                                    .fill(isHovered ? Color.white.opacity(0.15) : Color.clear)
                            )
                            .help("Click card to copy")
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .liquidPillStyle(cornerRadius: 12, isHovered: isHovered)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isRecentlyCopied ? AnyShapeStyle(GlassTheme.accentEmerald.opacity(0.8)) : (isHovered ? AnyShapeStyle(GlassTheme.liquidSpecularHoverBorder) : AnyShapeStyle(GlassTheme.subtleSpecularBorder)), lineWidth: 0.65)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
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
