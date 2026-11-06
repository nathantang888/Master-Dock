import SwiftUI
import MasterDockCore
import MasterDockServices

public struct AppFolderSectionView: View {
    @ObservedObject public var appLauncher: AppLauncherService
    @ObservedObject public var folderService: FolderService
    @State private var showingAppPicker = false
    @State private var isAppDropTarget = false
    
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
                    count: appLauncher.favoriteApps.count,
                    actionTitle: "Edit",
                    onAction: { showingAppPicker = true }
                )
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(appLauncher.favoriteApps) { app in
                            AppIconItem(app: app) {
                                appLauncher.launchApp(app)
                            }
                            .contextMenu {
                                Button("Move Left") { withAnimation(.spring(response: 0.3, dampingFraction: 1)) { appLauncher.moveFavorite(app, by: -1) } }
                                    .disabled(appLauncher.favoriteApps.first?.id == app.id)
                                Button("Move Right") { withAnimation(.spring(response: 0.3, dampingFraction: 1)) { appLauncher.moveFavorite(app, by: 1) } }
                                    .disabled(appLauncher.favoriteApps.last?.id == app.id)
                                Divider()
                                Button("Remove from Favorites", role: .destructive) {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 1)) { appLauncher.removeFavorite(app) }
                                }
                            }
                        }
                        AddAppTile { showingAppPicker = true }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                    .background(
                        ScrollEdgeFadeObserver(axis: .horizontal, fadeLength: 20.0, fadeThreshold: 14.0)
                    )
                }
                // Drop an app from Finder here to add it.
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(GlassTheme.accentBlue, lineWidth: 2)
                        .opacity(isAppDropTarget ? 1 : 0)
                        .allowsHitTesting(false)
                )
                .dropDestination(for: URL.self) { urls, _ in
                    let apps = urls.filter { $0.pathExtension == "app" }
                    withAnimation(.spring(response: 0.3, dampingFraction: 1)) { apps.forEach { appLauncher.addFavorite(at: $0) } }
                    return !apps.isEmpty
                } isTargeted: { targeted in
                    withAnimation(.easeOut(duration: 0.12)) { isAppDropTarget = targeted }
                }
            }
            .sheet(isPresented: $showingAppPicker) {
                FavoriteAppsPicker(appLauncher: appLauncher, close: { showingAppPicker = false })
                    .frame(width: AISheetMetrics.width, height: 460)
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
                        FolderItemCard(folder: folder, isMissing: !folderService.exists(folder)) {
                            folderService.openFolder(folder)
                        }
                        .contextMenu {
                            Button("Show in Finder") { folderService.revealInFinder(folder) }
                                .disabled(!folderService.exists(folder))
                            Button("Change Folder...") { folderService.relocateFolder(folder) }
                            Divider()
                            Button("Move Earlier") { withAnimation(.spring(response: 0.3, dampingFraction: 1)) { folderService.moveFolder(folder, by: -1) } }
                                .disabled(folderService.favoriteFolders.first?.id == folder.id)
                            Button("Move Later") { withAnimation(.spring(response: 0.3, dampingFraction: 1)) { folderService.moveFolder(folder, by: 1) } }
                                .disabled(folderService.favoriteFolders.last?.id == folder.id)
                            Divider()
                            Button("Remove", role: .destructive) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 1)) { folderService.removeFolder(folder) }
                            }
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
        .buttonStyle(.pressable)
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                self.isHovered = hovering
            }
        }
    }
}

private struct FolderItemCard: View {
    let folder: FolderItem
    var isMissing: Bool = false
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
                    .foregroundColor(.white.opacity(isMissing ? 0.5 : 1))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                
                Spacer(minLength: 2)
                
                Image(systemName: isMissing ? "exclamationmark.circle" : "arrow.up.right")
                    .font(.system(size: 10))
                    .foregroundColor(isMissing ? .orange.opacity(0.8) : .white.opacity(0.4))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .liquidPillStyle(cornerRadius: 10, isHovered: isHovered)
        }
        .buttonStyle(.pressable)
        .help(isMissing ? "This folder can't be found. Click to choose where it is now." : folder.url.path)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                self.isHovered = hovering
            }
        }
    }
}

/// The "+" at the end of the favorites row.
private struct AddAppTile: View {
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 40, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1.2, dash: [4, 3]))
                    )
                Text("Add")
                    .font(AppTypography.caption)
                    .foregroundColor(.white.opacity(0.6))
                    .frame(width: 54)
            }
            .scaleEffect(isHovered ? 1.06 : 1.0)
        }
        .buttonStyle(.pressable)
        .help("Choose your favorite apps")
        .onHover { hovering in
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) { isHovered = hovering }
        }
    }
}

/// Pick, remove and reorder favorite apps.
private struct FavoriteAppsPicker: View {
    @ObservedObject var appLauncher: AppLauncherService
    let close: () -> Void
    @State private var search = ""
    
    private var results: [AppItem] {
        let query = search.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return appLauncher.allApps }
        return appLauncher.allApps.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Favorite Apps")
                    .font(AppTypography.titleMedium)
                Spacer()
                Button("Done", action: close)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
            
            if !appLauncher.favoriteApps.isEmpty {
                Text("Your favorites (drag to reorder)")
                    .font(AppTypography.captionBold)
                    .foregroundColor(.secondary)
                List {
                    ForEach(appLauncher.favoriteApps) { app in
                        HStack(spacing: 8) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                                .resizable()
                                .frame(width: 20, height: 20)
                            Text(app.name)
                                .lineLimit(1)
                            Spacer()
                            Button(action: { withAnimation { appLauncher.removeFavorite(app) } }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                            .help("Remove")
                        }
                    }
                    .onMove { source, destination in
                        appLauncher.moveFavorites(fromOffsets: source, toOffset: destination)
                    }
                }
                .listStyle(.plain)
                .frame(height: min(CGFloat(appLauncher.favoriteApps.count) * 30 + 8, 132))
            }
            
            Text("Add apps")
                .font(AppTypography.captionBold)
                .foregroundColor(.secondary)
            TextField("Search apps", text: $search)
                .textFieldStyle(.roundedBorder)
            List(results) { app in
                let isFavorite = appLauncher.isFavorite(app)
                Button(action: {
                    withAnimation {
                        if isFavorite { appLauncher.removeFavorite(app) } else { appLauncher.addFavorite(at: app.bundleURL) }
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: app.bundleURL.path))
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text(app.name)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: isFavorite ? "checkmark.circle.fill" : "plus.circle")
                            .foregroundColor(isFavorite ? GlassTheme.accentBlue : .secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
            
            Text("Tip: you can also drag an app from Finder onto the Favorite Apps row, or right click an icon to move or remove it.")
                .font(AppTypography.micro)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
    }
}
