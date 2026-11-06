import Foundation
import AppKit
import Combine

public struct AppItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let bundleIdentifier: String?
    public let bundleURL: URL
    public var isFavorite: Bool
    public var isRunning: Bool
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        bundleIdentifier: String? = nil,
        bundleURL: URL,
        isFavorite: Bool = false,
        isRunning: Bool = false
    ) {
        self.id = id
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.bundleURL = bundleURL
        self.isFavorite = isFavorite
        self.isRunning = isRunning
    }
}

public final class AppLauncherService: ObservableObject, AppLauncherServiceProtocol {
    public static let shared = AppLauncherService()
    
    @Published public private(set) var favoriteApps: [AppItem] = []
    @Published public private(set) var runningApps: [AppItem] = []
    @Published public private(set) var allApps: [AppItem] = []
    
    private let storageKey = "favorite_apps"
    
    public init() {
        scanApplications()
        setupWorkspaceObservers()
    }
    
    public func scanApplications() {
        let appDirs = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app").deletingLastPathComponent(),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]
        
        var discovered: [AppItem] = []
        let runningBundleIds = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        
        for dir in appDirs {
            guard let enumerator = FileManager.default.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isApplicationKey],
                options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
            ) else { continue }
            
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "app",
                   !discovered.contains(where: { $0.bundleURL == fileURL }),
                   dir.path != "/System/Library/CoreServices" || fileURL.lastPathComponent == "Finder.app" {
                    let name = fileURL.deletingPathExtension().lastPathComponent
                    let bundle = Bundle(url: fileURL)
                    let bundleId = bundle?.bundleIdentifier
                    let isRunning = bundleId != nil ? runningBundleIds.contains(bundleId!) : false
                    
                    let item = AppItem(
                        id: fileURL.path,
                        name: name,
                        bundleIdentifier: bundleId,
                        bundleURL: fileURL,
                        isFavorite: false,
                        isRunning: isRunning
                    )
                    discovered.append(item)
                }
            }
        }
        
        self.allApps = discovered.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        loadFavorites()
    }
    
    private func setupWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updateRunningStatus()
        }
        center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
            self?.updateRunningStatus()
        }
    }
    
    private func updateRunningStatus() {
        let runningBundleIds = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        
        for i in 0..<favoriteApps.count {
            if let bid = favoriteApps[i].bundleIdentifier {
                favoriteApps[i].isRunning = runningBundleIds.contains(bid)
            }
        }
        
        runningApps = allApps.filter { app in
            if let bid = app.bundleIdentifier {
                return runningBundleIds.contains(bid)
            }
            return false
        }
    }
    
    public func launchApp(_ app: AppItem) {
        NSWorkspace.shared.openApplication(at: app.bundleURL, configuration: NSWorkspace.OpenConfiguration()) { _, error in
            if let error = error {
                print("[AppLauncherService] Failed to open app: \(error)")
            }
        }
    }
    
    public func toggleFavorite(_ app: AppItem) {
        if let idx = favoriteApps.firstIndex(where: { $0.bundleURL == app.bundleURL }) {
            favoriteApps.remove(at: idx)
        } else {
            var newApp = app
            newApp.isFavorite = true
            favoriteApps.append(newApp)
        }
        persistFavorites()
    }
    
    public func isFavorite(_ app: AppItem) -> Bool {
        favoriteApps.contains { $0.bundleURL == app.bundleURL }
    }
    
    /// Adds any app, including one dragged in from Finder.
    public func addFavorite(at url: URL) {
        guard url.pathExtension == "app", !favoriteApps.contains(where: { $0.bundleURL == url }) else { return }
        let bundleId = Bundle(url: url)?.bundleIdentifier
        let running = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleIdentifier })
        favoriteApps.append(AppItem(
            id: url.path,
            name: FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: ""),
            bundleIdentifier: bundleId,
            bundleURL: url,
            isFavorite: true,
            isRunning: bundleId.map { running.contains($0) } ?? false
        ))
        persistFavorites()
    }
    
    public func removeFavorite(_ app: AppItem) {
        favoriteApps.removeAll { $0.bundleURL == app.bundleURL }
        persistFavorites()
    }
    
    /// Moves a favorite left (negative) or right (positive).
    public func moveFavorite(_ app: AppItem, by offset: Int) {
        guard let index = favoriteApps.firstIndex(where: { $0.bundleURL == app.bundleURL }) else { return }
        let target = min(max(index + offset, 0), favoriteApps.count - 1)
        guard target != index else { return }
        let item = favoriteApps.remove(at: index)
        favoriteApps.insert(item, at: target)
        persistFavorites()
    }
    
    public func moveFavorites(fromOffsets source: IndexSet, toOffset destination: Int) {
        favoriteApps.move(fromOffsets: source, toOffset: destination)
        persistFavorites()
    }
    
    private func persistFavorites() {
        PersistenceController.shared.save(favoriteApps, forKey: storageKey)
        // Remember that the list was chosen on purpose, even if it's empty.
        UserDefaults.standard.set(true, forKey: "favorite_apps_customized")
    }
    
    private func loadFavorites() {
        if let saved = PersistenceController.shared.load([AppItem].self, forKey: storageKey),
           !saved.isEmpty || UserDefaults.standard.bool(forKey: "favorite_apps_customized") {
            // Skip apps that were deleted from the Mac.
            self.favoriteApps = saved.filter { FileManager.default.fileExists(atPath: $0.bundleURL.path) }
        } else {
            // Default favorites
            let defaultNames = ["Safari", "Terminal", "Finder", "Notes", "Music", "System Settings"]
            self.favoriteApps = allApps.filter { defaultNames.contains($0.name) }
            for i in 0..<favoriteApps.count {
                favoriteApps[i].isFavorite = true
            }
        }
        updateRunningStatus()
    }
}
