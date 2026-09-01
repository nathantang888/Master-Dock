import SwiftUI
import MasterDockCore
import MasterDockServices

public struct AppFolderSectionView: View {
    @ObservedObject public var appLauncher: AppLauncherService
    @ObservedObject public var folderService: FolderService
    
    public init(appLauncher: AppLauncherService, folderService: FolderService) {
        self.appLauncher = appLauncher
        self.folderService = folderService
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Favorite Apps
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(
                    title: "Favorite Apps",
                    iconSystemName: "square.grid.2x2.fill",
                    count: appLauncher.favoriteApps.count
                )
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(appLauncher.favoriteApps) { app in
                            AppIconItem(app: app) {
                                appLauncher.launchApp(app)
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
            
            // Favorite Folders
            VStack(alignment: .leading, spacing: 8) {
                SectionHeader(
                    title: "Quick Folders",
                    iconSystemName: "folder.fill",
                    count: folderService.favoriteFolders.count,
                    actionTitle: "+ Add",
                    onAction: { folderService.chooseFolder() }
                )
                
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(folderService.favoriteFolders) { folder in
                        FolderItemCard(folder: folder) {
                            folderService.openFolder(folder)
                        }
                    }
                }
            }
        }
    }
}

private struct AppIconItem: View {
    let app: AppItem
    let onLaunch: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onLaunch) {
            VStack(spacing: 4) {
                ZStack(alignment: .bottomTrailing) {
                    // App icon
                    Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                        .resizable()
                        .frame(width: 40, height: 40)
                        .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                    
                    // Running Dot Indicator
                    if app.isRunning {
                        Circle()
                            .fill(GlassTheme.accentEmerald)
                            .frame(width: 8, height: 8)
                            .overlay(Circle().stroke(Color.black, lineWidth: 1.5))
                            .offset(x: 2, y: 2)
                    }
                }
                
                Text(app.name)
                    .font(AppTypography.caption)
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
                    .frame(width: 54)
            }
            .scaleEffect(isHovered ? 1.08 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                self.isHovered = hovering
            }
        }
    }
}

private struct FolderItemCard: View {
    let folder: FolderItem
    let onOpen: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 8) {
                Image(systemName: folder.iconSystemName)
                    .font(.system(size: 16))
                    .foregroundColor(GlassTheme.accentCyan)
                
                Text(folder.name)
                    .font(AppTypography.bodyBold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .liquidPillStyle(cornerRadius: 10, isHovered: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
    }
}
