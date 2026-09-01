import Foundation
import AppKit

public protocol ClipboardServiceProtocol: AnyObject {
    var items: [ClipboardItem] { get }
    func copyItemToPasteboard(_ item: ClipboardItem)
    func pasteItemDirectly(_ item: ClipboardItem)
    func clearHistory()
}

public protocol MediaServiceProtocol: AnyObject {
    var currentTrack: MediaTrack? { get }
    var isPlaying: Bool { get }
    var activeSource: MediaSource { get }
    var playbackPosition: Double { get }
    var trackDuration: Double { get }
    var volume: Double { get }
    var isShuffleEnabled: Bool { get }
    var repeatMode: RepeatMode { get }
    var isLiked: Bool { get }
    var platforms: [MediaPlatformInfo] { get }
    var playlists: [MediaPlaylist] { get }
    
    func playPause()
    func nextTrack()
    func previousTrack()
    func rewind(seconds: Double)
    func fastForward(seconds: Double)
    func seek(to position: Double)
    func setVolume(_ newVolume: Double)
    func toggleShuffle()
    func cycleRepeatMode()
    func toggleLiked()
    func selectSource(_ source: MediaSource)
    func refreshPlaylists()
    func playPlaylist(_ playlist: MediaPlaylist)
    func playTrackItem(_ item: MediaTrackItem)
}

public protocol CalendarServiceProtocol: AnyObject {
    var todayEvents: [CalendarMeeting] { get }
    func refreshEvents() async
}

public protocol WallpaperServiceProtocol: AnyObject {
    var wallpapers: [WallpaperItem] { get }
    func setWallpaper(_ item: WallpaperItem)
}

public protocol AppLauncherServiceProtocol: AnyObject {
    var favoriteApps: [AppItem] { get }
    var runningApps: [AppItem] { get }
    func launchApp(_ app: AppItem)
    func toggleFavorite(_ app: AppItem)
}

public protocol FolderServiceProtocol: AnyObject {
    var favoriteFolders: [FolderItem] { get }
    func openFolder(_ folder: FolderItem)
    func addFolder(url: URL)
    func removeFolder(_ folder: FolderItem)
}

public protocol ChecklistServiceProtocol: AnyObject {
    var items: [ChecklistItem] { get }
    func addItem(title: String)
    func toggleItem(_ item: ChecklistItem)
    func removeItem(_ item: ChecklistItem)
    func clearCompleted()
}

public protocol SystemStatsServiceProtocol: AnyObject {
    var cpuUsage: Double { get }
    var memoryUsage: Double { get }
    var diskUsage: Double { get }
}
