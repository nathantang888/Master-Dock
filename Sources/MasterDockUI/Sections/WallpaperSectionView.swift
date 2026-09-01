import SwiftUI
import AppKit
import ImageIO
import MasterDockCore
import MasterDockServices

public final class WallpaperThumbnailCache: @unchecked Sendable {
    public static let shared = WallpaperThumbnailCache()
    private let cache = NSCache<NSURL, NSImage>()
    
    private init() {
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024 // 50 MB
    }
    
    public func getThumbnail(for url: URL) -> NSImage? {
        return cache.object(forKey: url as NSURL)
    }
    
    public func loadThumbnail(for url: URL) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }
        
        return await Task.detached(priority: .userInitiated) { () -> NSImage? in
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 240
            ]
            guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
                return nil
            }
            let thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: 105, height: 64))
            self.cache.setObject(thumbnail, forKey: url as NSURL)
            return thumbnail
        }.value
    }
}

public struct WallpaperSectionView: View {
    @ObservedObject public var wallpaperService: WallpaperService
    
    public init(wallpaperService: WallpaperService) {
        self.wallpaperService = wallpaperService
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(
                title: "macOS Desktop Wallpapers",
                iconSystemName: "photo.on.rectangle.angled",
                count: wallpaperService.wallpapers.count,
                actionTitle: "+ Custom...",
                onAction: { wallpaperService.chooseCustomWallpaper() }
            )
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(wallpaperService.wallpapers) { item in
                        WallpaperCard(
                            item: item,
                            isActive: wallpaperService.currentWallpaperName == item.name
                        ) {
                            wallpaperService.setWallpaper(item)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .background(
                    ScrollEdgeFadeObserver(axis: .horizontal, fadeLength: 20.0, fadeThreshold: 14.0)
                )
            }
        }
    }
}

private struct WallpaperCard: View {
    let item: WallpaperItem
    let isActive: Bool
    let onSelect: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 4) {
                ZStack(alignment: .topTrailing) {
                    // Async Cached Thumbnail with Smooth Placeholder
                    AsyncWallpaperThumbnail(item: item)
                        .frame(width: 105, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(isActive ? AnyShapeStyle(GlassTheme.accentCyan) : AnyShapeStyle(GlassTheme.subtleSpecularBorder), lineWidth: isActive ? 2.0 : 0.8)
                        )
                        .shadow(color: isActive ? GlassTheme.accentCyan.opacity(0.45) : Color.black.opacity(0.25), radius: isActive ? 6 : 3, x: 0, y: 2)
                    
                    // Active Checkmark Badge
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .background(Circle().fill(GlassTheme.accentBlue))
                            .padding(4)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                
                Text(item.name)
                    .font(AppTypography.captionBold)
                    .foregroundColor(isActive ? GlassTheme.accentCyan : .white.opacity(0.9))
                    .lineLimit(1)
                    .frame(width: 105, alignment: .leading)
            }
            .scaleEffect(isHovered ? 1.04 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                self.isHovered = hovering
            }
        }
    }
}

private struct AsyncWallpaperThumbnail: View {
    let item: WallpaperItem
    @State private var thumbnailImage: NSImage?
    
    var body: some View {
        ZStack {
            // Placeholder Gradient
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: item.primaryColorHex),
                            Color(hex: item.secondaryColorHex)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            // Decoded Thumbnail Image
            if let image = thumbnailImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity.animation(.easeInOut(duration: 0.18)))
            }
        }
        .task(id: item.id) {
            if let url = item.fileURL {
                if let fastCache = WallpaperThumbnailCache.shared.getThumbnail(for: url) {
                    self.thumbnailImage = fastCache
                } else {
                    let loaded = await WallpaperThumbnailCache.shared.loadThumbnail(for: url)
                    await MainActor.run {
                        self.thumbnailImage = loaded
                    }
                }
            }
        }
    }
}

private extension Color {
    init(hex: String) {
        let cleanHex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleanHex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch cleanHex.count {
        case 6: // RGB
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 120, 120, 120)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
