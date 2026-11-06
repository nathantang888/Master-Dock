import Foundation
import AppKit
import Combine

public struct FolderItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let url: URL
    public let iconSystemName: String
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        url: URL,
        iconSystemName: String = "folder.fill"
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.iconSystemName = iconSystemName
    }
}

public final class FolderService: ObservableObject, FolderServiceProtocol {
    public static let shared = FolderService()
    
    @Published public private(set) var favoriteFolders: [FolderItem] = []
    private let storageKey = "favorite_folders"
    
    public init() {
        loadFolders()
    }
    
    public func exists(_ folder: FolderItem) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: folder.url.path, isDirectory: &isDir) && isDir.boolValue
    }
    
    /// Opens the folder in Finder. If it was moved or deleted, lets you pick where it is now.
    public func openFolder(_ folder: FolderItem) {
        if exists(folder) {
            NSWorkspace.shared.open(folder.url)
        } else {
            relocateFolder(folder)
        }
    }
    
    public func revealInFinder(_ folder: FolderItem) {
        NSWorkspace.shared.activateFileViewerSelecting([folder.url])
    }
    
    /// Swap a folder for a different one, keeping its spot in the list.
    public func relocateFolder(_ folder: FolderItem) {
        guard let url = pickFolder(message: "\(folder.name) couldn't be found. Choose the folder to use instead.") ,
              let index = favoriteFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        favoriteFolders[index] = FolderItem(id: url.path, name: url.lastPathComponent, url: url, iconSystemName: "folder.fill")
        persistFolders()
    }
    
    public func moveFolder(_ folder: FolderItem, by offset: Int) {
        guard let index = favoriteFolders.firstIndex(where: { $0.id == folder.id }) else { return }
        let target = min(max(index + offset, 0), favoriteFolders.count - 1)
        guard target != index else { return }
        let item = favoriteFolders.remove(at: index)
        favoriteFolders.insert(item, at: target)
        persistFolders()
    }
    
    public func addFolder(url: URL) {
        let name = url.lastPathComponent
        let item = FolderItem(
            id: url.path,
            name: name,
            url: url,
            iconSystemName: "folder.fill"
        )
        if !favoriteFolders.contains(where: { $0.url == url }) {
            favoriteFolders.append(item)
            persistFolders()
        }
    }
    
    public func chooseFolder() {
        if let url = pickFolder(message: "Choose a folder to add to Quick Folders.") {
            addFolder(url: url)
        }
    }
    
    private func pickFolder(message: String) -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.message = message
        panel.prompt = "Choose"
        // The dock is a floating panel, so bring the app forward or the picker opens behind other windows.
        NSApp.activate(ignoringOtherApps: true)
        panel.level = .floating
        return panel.runModal() == .OK ? panel.url : nil
    }
    
    public func removeFolder(_ folder: FolderItem) {
        favoriteFolders.removeAll { $0.id == folder.id }
        persistFolders()
    }
    
    private func persistFolders() {
        PersistenceController.shared.save(favoriteFolders, forKey: storageKey)
        UserDefaults.standard.set(true, forKey: "favorite_folders_customized")
    }
    
    private func loadFolders() {
        if let saved = PersistenceController.shared.load([FolderItem].self, forKey: storageKey),
           !saved.isEmpty || UserDefaults.standard.bool(forKey: "favorite_folders_customized") {
            // The old default "Developer" folder doesn't exist on most Macs, so drop it if it's missing.
            self.favoriteFolders = saved.filter { $0.name != "Developer" || exists($0) }
            if favoriteFolders.count != saved.count { persistFolders() }
        } else {
            let fm = FileManager.default
            let home = fm.homeDirectoryForCurrentUser
            
            self.favoriteFolders = [
                FolderItem(name: "Downloads", url: home.appendingPathComponent("Downloads"), iconSystemName: "arrow.down.circle.fill"),
                FolderItem(name: "Documents", url: home.appendingPathComponent("Documents"), iconSystemName: "doc.fill"),
                FolderItem(name: "Desktop", url: home.appendingPathComponent("Desktop"), iconSystemName: "macwindow"),
                FolderItem(name: "Applications", url: URL(fileURLWithPath: "/Applications"), iconSystemName: "square.grid.2x2.fill")
            ]
        }
    }
}
