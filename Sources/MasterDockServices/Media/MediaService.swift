import Foundation
import AppKit
import Combine
import SwiftUI

public final class MediaService: ObservableObject, MediaServiceProtocol {
    public static let shared = MediaService()
    
    // Published Playback State
    @Published public private(set) var currentTrack: MediaTrack?
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var activeSource: MediaSource = .none
    @Published public private(set) var playbackPosition: Double = 0.0
    @Published public private(set) var trackDuration: Double = 0.0
    @Published public private(set) var volume: Double = 0.8
    @Published public private(set) var isShuffleEnabled: Bool = false
    @Published public private(set) var repeatMode: RepeatMode = .off
    @Published public private(set) var isLiked: Bool = false
    
    // Published Platform & Playlist State
    @Published public private(set) var platforms: [MediaPlatformInfo] = []
    @Published public private(set) var playlists: [MediaPlaylist] = []
    @Published public var preferredSource: MediaSource = .spotify
    @Published public var customPlaylists: [MediaPlaylist] = []
    
    // Live Song Search
    @Published public private(set) var searchResults: [MediaTrackItem] = []
    @Published public private(set) var isSearchingSongs: Bool = false
    private var searchTask: URLSessionDataTask? = nil
    
    private var pollTimer: Timer?
    private var positionTimer: Timer?
    private let customPlaylistsKey = "masterdock_custom_playlists_v1"
    private let preferredSourceKey = "masterdock_preferred_media_source"
    private let likedTracksKey = "masterdock_liked_tracks_v1"
    private var likedTrackIDs: Set<String> = []
    
    // Artwork caching & asynchronous fetchers
    private let artworkCache = NSCache<NSString, NSData>()
    private var inFlightArtworkFetches: Set<String> = []
    private let artworkLock = NSLock()
    
    public init() {
        loadPersistedData()
        updatePlatformStatus()
        loadDefaultPlaylists()
        startPolling()
        startPositionTimer()
    }
    
    // MARK: - Polling & Timers
    
    public func startPolling() {
        refreshState()
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshState()
        }
    }
    
    public func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
        positionTimer?.invalidate()
        positionTimer = nil
    }
    
    private var isUserInitiatedSkip: Bool = false
    
    private func startPositionTimer() {
        positionTimer?.invalidate()
        // Smooth 0.5s local progress tick during playback
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying, self.trackDuration > 0 else { return }
            if self.playbackPosition < self.trackDuration {
                self.playbackPosition = min(self.trackDuration, self.playbackPosition + 0.5)
            }
            
            // Repeat One Auto-Loop: restart from 0:00 when reaching end of track
            if self.repeatMode == .one && self.trackDuration > 5.0 && self.playbackPosition >= self.trackDuration - 0.75 {
                self.restartCurrentTrack()
            }
        }
    }
    
    // MARK: - State Refresh & Multi-Platform Queries
    
    public func refreshState() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.updatePlatformStatusSync()
            
            let currentSource = self.activeSource != .none ? self.activeSource : (self.preferredSource != .none ? self.preferredSource : .spotify)
            
            let spotifyTrack = self.querySpotify()
            let appleTrack = self.queryAppleMusic()
            let ytTrack = self.queryYouTubeMusic()
            let webTrack = self.queryGenericBrowsers()
            
            // 1. If currently on a specific platform and it has valid track data, strictly prioritize it!
            if currentSource == .spotify, let sp = spotifyTrack {
                self.applyTrack(sp, source: .spotify)
                return
            } else if currentSource == .appleMusic, let ap = appleTrack {
                self.applyTrack(ap, source: .appleMusic)
                return
            } else if currentSource == .youtubeMusic, let yt = ytTrack {
                self.applyTrack(yt, source: .youtubeMusic)
                return
            }
            
            // 2. If the current source has no track, check if any other platform is actively PLAYING:
            if let sp = spotifyTrack, sp.isPlaying {
                self.applyTrack(sp, source: .spotify)
                return
            }
            if let ap = appleTrack, ap.isPlaying {
                self.applyTrack(ap, source: .appleMusic)
                return
            }
            if let yt = ytTrack, yt.isPlaying {
                self.applyTrack(yt, source: .youtubeMusic)
                return
            }
            if let wb = webTrack, wb.isPlaying {
                self.applyTrack(wb, source: wb.source)
                return
            }
            
            // 3. If nothing is playing, check available platform tracks:
            if let sp = spotifyTrack {
                self.applyTrack(sp, source: .spotify)
                return
            }
            if let ap = appleTrack {
                self.applyTrack(ap, source: .appleMusic)
                return
            }
            if let yt = ytTrack {
                self.applyTrack(yt, source: .youtubeMusic)
                return
            }
            if let wb = webTrack {
                self.applyTrack(wb, source: wb.source)
                return
            }
            
            // 4. Fallback Standby State (Single active platform only)
            DispatchQueue.main.async {
                let defaultSource = currentSource != .none ? currentSource : .spotify
                if self.currentTrack == nil || self.currentTrack?.title == "Ready to Play" {
                    self.currentTrack = MediaTrack(
                        title: "Ready to Play",
                        artist: "\(defaultSource.shortName)",
                        album: "\(defaultSource.shortName) Player",
                        duration: 180,
                        position: 0,
                        artworkData: nil,
                        artworkURL: nil,
                        isPlaying: false,
                        isLiked: false,
                        source: defaultSource
                    )
                    self.isPlaying = false
                    self.activeSource = defaultSource
                    self.playbackPosition = 0
                    self.trackDuration = 180
                } else if self.isPlaying {
                    self.isPlaying = false
                }
            }
        }
    }
    
    private func applyTrack(_ track: MediaTrack, source: MediaSource) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let previousSource = self.activeSource
            let isTrackLiked = self.likedTrackIDs.contains(track.id)
            let isSameTrack = (self.currentTrack?.title == track.title && self.currentTrack?.artist == track.artist)
            let existingArtwork = isSameTrack ? self.currentTrack?.artworkData : nil
            let existingArtURL = isSameTrack ? self.currentTrack?.artworkURL : nil
            
            let finalTrack = MediaTrack(
                title: track.title,
                artist: track.artist,
                album: track.album,
                duration: track.duration,
                position: track.position,
                artworkData: track.artworkData ?? existingArtwork,
                artworkURL: track.artworkURL ?? existingArtURL,
                isPlaying: track.isPlaying,
                isLiked: isTrackLiked,
                source: source,
                trackId: track.trackId
            )
            
            self.currentTrack = finalTrack
            self.isPlaying = track.isPlaying
            self.activeSource = source
            
            if previousSource != source {
                self.refreshPlaylists()
            }
            
            if track.duration > 0 {
                self.trackDuration = track.duration
            }
            // Sync position only if significant delta to prevent jitter
            if abs(self.playbackPosition - track.position) > 2.0 || !track.isPlaying {
                self.playbackPosition = track.position
            }
            
            // Asynchronously fetch cover art if not yet loaded
            if finalTrack.artworkData == nil && !finalTrack.title.isEmpty && finalTrack.title != "Ready to Play" {
                self.fetchArtworkIfNeeded(for: finalTrack)
            }
        }
    }
    
    // MARK: - Artwork Fetching & Caching
    
    private func fetchArtworkIfNeeded(for track: MediaTrack) {
        let trackKey = track.id
        artworkLock.lock()
        if inFlightArtworkFetches.contains(trackKey) {
            artworkLock.unlock()
            return
        }
        inFlightArtworkFetches.insert(trackKey)
        artworkLock.unlock()
        
        // 1. Direct Artwork URL (e.g. Spotify CDN)
        if let url = track.artworkURL {
            let urlKey = url.absoluteString as NSString
            if let cached = artworkCache.object(forKey: urlKey) {
                self.setArtworkData(cached as Data, for: trackKey, artworkURL: url)
                return
            }
            
            URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
                guard let self = self, let data = data, error == nil, NSImage(data: data) != nil else {
                    self?.finishArtworkFetch(for: trackKey)
                    return
                }
                self.artworkCache.setObject(data as NSData, forKey: urlKey)
                self.setArtworkData(data, for: trackKey, artworkURL: url)
            }.resume()
            return
        }
        
        // 2. iTunes Search API for Apple Music, YouTube Music, Browser, etc.
        guard !track.title.isEmpty, track.title != "Ready to Play" else {
            finishArtworkFetch(for: trackKey)
            return
        }
        
        let searchKey = "search:\(track.title):\(track.artist)" as NSString
        if let cached = artworkCache.object(forKey: searchKey) {
            self.setArtworkData(cached as Data, for: trackKey)
            return
        }
        
        let query = "\(track.title) \(track.artist)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let searchURL = URL(string: "https://itunes.apple.com/search?term=\(query)&entity=song&limit=1") else {
            finishArtworkFetch(for: trackKey)
            return
        }
        
        URLSession.shared.dataTask(with: searchURL) { [weak self] data, _, error in
            guard let self = self, let data = data, error == nil else {
                self?.finishArtworkFetch(for: trackKey)
                return
            }
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let first = results.first,
               let artUrlString = (first["artworkUrl100"] as? String)?.replacingOccurrences(of: "100x100bb.jpg", with: "600x600bb.jpg"),
               let artURL = URL(string: artUrlString) {
                
                URLSession.shared.dataTask(with: artURL) { [weak self] imgData, _, _ in
                    guard let self = self, let imgData = imgData, NSImage(data: imgData) != nil else {
                        self?.finishArtworkFetch(for: trackKey)
                        return
                    }
                    self.artworkCache.setObject(imgData as NSData, forKey: searchKey)
                    self.setArtworkData(imgData, for: trackKey, artworkURL: artURL)
                }.resume()
            } else {
                self.finishArtworkFetch(for: trackKey)
            }
        }.resume()
    }
    
    private func setArtworkData(_ data: Data, for trackKey: String, artworkURL: URL? = nil) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let current = self.currentTrack, current.id == trackKey else {
                self?.finishArtworkFetch(for: trackKey)
                return
            }
            self.currentTrack = MediaTrack(
                title: current.title,
                artist: current.artist,
                album: current.album,
                duration: current.duration,
                position: current.position,
                artworkData: data,
                artworkURL: artworkURL ?? current.artworkURL,
                isPlaying: current.isPlaying,
                isLiked: current.isLiked,
                source: current.source,
                trackId: current.trackId
            )
            self.finishArtworkFetch(for: trackKey)
        }
    }
    
    private func finishArtworkFetch(for trackKey: String) {
        artworkLock.lock()
        inFlightArtworkFetches.remove(trackKey)
        artworkLock.unlock()
    }
    
    // MARK: - Platform Queries
    
    private func querySpotify() -> MediaTrack? {
        let script = """
        if application "Spotify" is running then
            tell application "Spotify"
                try
                    set pState to (player state as string)
                    if pState is not "stopped" then
                        set trackName to name of current track
                        set artistName to artist of current track
                        set albumName to album of current track
                        set trackDuration to (duration of current track) / 1000
                        set trackPos to player position
                        set isPlay to (player state is playing)
                        set artUrl to artwork url of current track
                        set trackUri to spotify url of current track
                        set isShuff to shuffling
                        set isRep to repeating
                        set sndVol to sound volume
                        return trackName & "|||" & artistName & "|||" & albumName & "|||" & trackDuration & "|||" & trackPos & "|||" & isPlay & "|||" & artUrl & "|||" & trackUri & "|||" & isShuff & "|||" & isRep & "|||" & sndVol
                    end if
                end try
            end tell
        end if
        return "NONE"
        """
        
        guard let output = runAppleScript(script), output != "NONE", !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        
        let title = parts[0]
        let artist = parts[1]
        let album = parts[2]
        let duration = Double(parts[3]) ?? 0.0
        let position = Double(parts[4]) ?? 0.0
        let isPlaying = parts[5].trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        let artworkURL = parts.count > 6 && !parts[6].isEmpty ? URL(string: parts[6]) : nil
        let trackId = parts.count > 7 ? parts[7] : nil
        
        if parts.count > 8 {
            let shuffling = parts[8].trimmingCharacters(in: .whitespacesAndNewlines) == "true"
            let repeating = parts.count > 9 && parts[9].trimmingCharacters(in: .whitespacesAndNewlines) == "true"
            let volumeVal = parts.count > 10 ? (Double(parts[10]) ?? 80.0) / 100.0 : 0.8
            
            DispatchQueue.main.async {
                self.isShuffleEnabled = shuffling
                if !repeating {
                    self.repeatMode = .off
                } else if self.repeatMode == .off {
                    self.repeatMode = .all
                }
                self.volume = volumeVal
            }
        }
        
        var initialArtworkData: Data? = nil
        if let artURL = artworkURL, let cached = artworkCache.object(forKey: artURL.absoluteString as NSString) {
            initialArtworkData = cached as Data
        }
        
        return MediaTrack(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            position: position,
            artworkData: initialArtworkData,
            artworkURL: artworkURL,
            isPlaying: isPlaying,
            source: .spotify,
            trackId: trackId
        )
    }
    
    private func queryAppleMusic() -> MediaTrack? {
        let script = """
        if application "Music" is running then
            tell application "Music"
                try
                    set pState to (player state as string)
                    if pState is not "stopped" then
                        set trackName to name of current track
                        set artistName to artist of current track
                        set albumName to album of current track
                        set trackDuration to duration of current track
                        set trackPos to player position
                        set isPlay to (player state is playing)
                        set isShuff to shuffle enabled
                        set songRep to (song repeat as string)
                        set sndVol to sound volume
                        return trackName & "|||" & artistName & "|||" & albumName & "|||" & trackDuration & "|||" & trackPos & "|||" & isPlay & "|||" & isShuff & "|||" & songRep & "|||" & sndVol
                    end if
                end try
            end tell
        end if
        return "NONE"
        """
        
        guard let output = runAppleScript(script), output != "NONE", !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 6 else { return nil }
        
        let title = parts[0]
        let artist = parts[1]
        let album = parts[2]
        let duration = Double(parts[3]) ?? 0.0
        let position = Double(parts[4]) ?? 0.0
        let isPlaying = parts[5].trimmingCharacters(in: .whitespacesAndNewlines) == "true"
        
        if parts.count > 6 {
            let shuffling = parts[6].trimmingCharacters(in: .whitespacesAndNewlines) == "true"
            let repString = parts.count > 7 ? parts[7].lowercased() : "off"
            let repMode: RepeatMode = repString.contains("one") ? .one : (repString.contains("all") ? .all : .off)
            let volumeVal = parts.count > 8 ? (Double(parts[8]) ?? 80.0) / 100.0 : 0.8
            
            DispatchQueue.main.async {
                self.isShuffleEnabled = shuffling
                self.repeatMode = repMode
                self.volume = volumeVal
            }
        }
        
        return MediaTrack(
            title: title,
            artist: artist,
            album: album,
            duration: duration,
            position: position,
            artworkData: nil,
            artworkURL: nil,
            isPlaying: isPlaying,
            source: .appleMusic,
            trackId: nil
        )
    }
    
    private func queryYouTubeMusic() -> MediaTrack? {
        // 1. Check for YouTube Music Desktop app (only if running and playing)
        let ytmDesktopScript = """
        if application "YouTube Music" is running then
            tell application "YouTube Music"
                try
                    set pState to player state
                    if pState is "playing" then
                        set trackTitle to name of current track
                        set artistName to artist of current track
                        return trackTitle & "|||" & artistName & "|||YouTube Music|||180|||0|||true"
                    end if
                end try
            end tell
        end if
        return "NONE"
        """
        
        if let output = runAppleScript(ytmDesktopScript), output != "NONE", !output.isEmpty {
            let parts = output.components(separatedBy: "|||")
            if parts.count >= 6 {
                return MediaTrack(
                    title: parts[0],
                    artist: parts[1],
                    album: parts[2],
                    duration: Double(parts[3]) ?? 180,
                    position: Double(parts[4]) ?? 0,
                    artworkData: nil,
                    artworkURL: nil,
                    isPlaying: parts[5].trimmingCharacters(in: .whitespacesAndNewlines) == "true",
                    source: .youtubeMusic
                )
            }
        }
        
        // 2. Check Chrome or Safari for active YouTube Music tabs ONLY IF video is actually playing!
        let browserYtScript = """
        if application "Google Chrome" is running then
            tell application "Google Chrome"
                repeat with w in windows
                    repeat with t in tabs of w
                        if URL of t contains "music.youtube.com" then
                            set res to execute t javascript "(function() { var v = document.querySelector('video'); if (v && !v.paused && v.duration > 0 && !v.ended) { return 'PLAYING|||' + document.title + '|||' + (v.duration || 180) + '|||' + (v.currentTime || 0); } return 'PAUSED'; })()"
                            if res starts with "PLAYING" then
                                return res
                            end if
                        end if
                    end repeat
                end repeat
            end tell
        end if
        return "NONE"
        """
        
        if let output = runAppleScript(browserYtScript), output.hasPrefix("PLAYING|||") {
            let parts = output.components(separatedBy: "|||")
            if parts.count >= 4 {
                var title = parts[1].replacingOccurrences(of: " - YouTube Music", with: "")
                var artist = "YouTube Music"
                if title.contains(" - ") {
                    let segments = title.components(separatedBy: " - ")
                    if segments.count >= 2 {
                        title = segments[0].trimmingCharacters(in: .whitespaces)
                        artist = segments[1].trimmingCharacters(in: .whitespaces)
                    }
                }
                let dur = Double(parts[2]) ?? 180
                let pos = Double(parts[3]) ?? 0
                return MediaTrack(
                    title: title,
                    artist: artist,
                    album: "YouTube Music",
                    duration: dur,
                    position: pos,
                    artworkData: nil,
                    artworkURL: nil,
                    isPlaying: true,
                    source: .youtubeMusic
                )
            }
        }
        
        return nil
    }
    
    private func queryGenericBrowsers() -> MediaTrack? {
        let script = """
        if application "Google Chrome" is running then
            tell application "Google Chrome"
                repeat with w in windows
                    repeat with t in tabs of w
                        set tUrl to URL of t
                        if tUrl contains "soundcloud.com" then
                            return "SOUNDCLOUD|||" & title of t
                        else if tUrl contains "tidal.com" then
                            return "TIDAL|||" & title of t
                        end if
                    end repeat
                end repeat
            end tell
        end if
        return "NONE"
        """
        
        guard let output = runAppleScript(script), output != "NONE", !output.isEmpty else { return nil }
        let parts = output.components(separatedBy: "|||")
        guard parts.count >= 2 else { return nil }
        
        let source: MediaSource = parts[0] == "SOUNDCLOUD" ? .soundCloud : (parts[0] == "TIDAL" ? .tidal : .webMedia)
        let title = parts[1].replacingOccurrences(of: " | SoundCloud", with: "").replacingOccurrences(of: " | TIDAL", with: "")
        
        return MediaTrack(
            title: title,
            artist: source.rawValue,
            album: "Web Audio Stream",
            duration: 200,
            position: self.playbackPosition,
            artworkData: nil,
            artworkURL: nil,
            isPlaying: self.isPlaying,
            source: source
        )
    }
    
    // MARK: - Playback Transport Controls
    
    public func playPause() {
        switch activeSource {
        case .spotify:
            _ = runAppleScript("tell application \"Spotify\" to playpause")
        case .appleMusic:
            _ = runAppleScript("tell application \"Music\" to playpause")
        case .youtubeMusic:
            controlYouTubeMusicPlayback(action: "playpause")
        default:
            sendSystemMediaKey(key: 16) // NX_KEYTYPE_PLAY
        }
        self.isPlaying.toggle()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.refreshState()
        }
    }
    
    public func nextTrack() {
        self.isUserInitiatedSkip = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.isUserInitiatedSkip = false
        }
        
        switch activeSource {
        case .spotify:
            _ = runAppleScript("tell application \"Spotify\" to next track")
        case .appleMusic:
            _ = runAppleScript("tell application \"Music\" to next track")
        case .youtubeMusic:
            controlYouTubeMusicPlayback(action: "next")
        default:
            sendSystemMediaKey(key: 17) // NX_KEYTYPE_NEXT
        }
        self.playbackPosition = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshState()
        }
    }
    
    public func previousTrack() {
        self.isUserInitiatedSkip = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.isUserInitiatedSkip = false
        }
        
        switch activeSource {
        case .spotify:
            _ = runAppleScript("tell application \"Spotify\" to previous track")
        case .appleMusic:
            _ = runAppleScript("tell application \"Music\" to previous track")
        case .youtubeMusic:
            controlYouTubeMusicPlayback(action: "previous")
        default:
            sendSystemMediaKey(key: 18) // NX_KEYTYPE_PREVIOUS
        }
        self.playbackPosition = 0
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.refreshState()
        }
    }
    
    public func restartCurrentTrack() {
        self.playbackPosition = 0.0
        switch activeSource {
        case .spotify:
            _ = runAppleScript("tell application \"Spotify\" to set player position to 0")
            _ = runAppleScript("tell application \"Spotify\" to play")
        case .appleMusic:
            _ = runAppleScript("tell application \"Music\" to set player position to 0")
            _ = runAppleScript("tell application \"Music\" to play")
        case .youtubeMusic:
            controlYouTubeMusicPlayback(action: "seek", value: 0)
        default:
            seek(to: 0.0)
        }
    }
    
    public func rewind(seconds: Double = 15.0) {
        let newPos = max(0.0, playbackPosition - seconds)
        seek(to: newPos)
    }
    
    public func fastForward(seconds: Double = 15.0) {
        let maxDuration = trackDuration > 0 ? trackDuration : 300.0
        let newPos = min(maxDuration, playbackPosition + seconds)
        seek(to: newPos)
    }
    
    public func seek(to position: Double) {
        let clampedPos = max(0.0, min(trackDuration > 0 ? trackDuration : 1000.0, position))
        self.playbackPosition = clampedPos
        
        switch activeSource {
        case .spotify:
            _ = runAppleScript("tell application \"Spotify\" to set player position to \(clampedPos)")
        case .appleMusic:
            _ = runAppleScript("tell application \"Music\" to set player position to \(clampedPos)")
        case .youtubeMusic:
            controlYouTubeMusicPlayback(action: "seek", value: clampedPos)
        default:
            break
        }
    }
    
    public func setVolume(_ newVolume: Double) {
        let clamped = max(0.0, min(1.0, newVolume))
        self.volume = clamped
        let intVal = Int(clamped * 100)
        
        switch activeSource {
        case .spotify:
            _ = runAppleScript("tell application \"Spotify\" to set sound volume to \(intVal)")
        case .appleMusic:
            _ = runAppleScript("tell application \"Music\" to set sound volume to \(intVal)")
        default:
            break
        }
    }
    
    public func toggleShuffle() {
        self.isShuffleEnabled.toggle()
        switch activeSource {
        case .spotify:
            _ = runAppleScript("tell application \"Spotify\" to set shuffling to \(isShuffleEnabled)")
        case .appleMusic:
            _ = runAppleScript("tell application \"Music\" to set shuffle enabled to \(isShuffleEnabled)")
        default:
            break
        }
    }
    
    public func cycleRepeatMode() {
        switch repeatMode {
        case .off:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .off
        }
        
        applyCurrentRepeatModeToPlayer()
    }
    
    public func setRepeatMode(_ mode: RepeatMode) {
        self.repeatMode = mode
        applyCurrentRepeatModeToPlayer()
    }
    
    private func applyCurrentRepeatModeToPlayer() {
        switch activeSource {
        case .spotify:
            let isRepeating = repeatMode != .off
            _ = runAppleScript("tell application \"Spotify\" to set repeating to \(isRepeating)")
        case .appleMusic:
            let scriptVal = repeatMode == .one ? "one" : (repeatMode == .all ? "all" : "off")
            _ = runAppleScript("tell application \"Music\" to set song repeat to \(scriptVal)")
        case .youtubeMusic:
            controlYouTubeMusicPlayback(action: "repeat", value: repeatMode == .one ? 1.0 : (repeatMode == .all ? 2.0 : 0.0))
        default:
            break
        }
    }
    
    public func toggleLiked() {
        if let current = currentTrack {
            let trackId = current.id
            if likedTrackIDs.contains(trackId) {
                likedTrackIDs.remove(trackId)
                isLiked = false
            } else {
                likedTrackIDs.insert(trackId)
                isLiked = true
            }
            persistLikedTracks()
        } else {
            isLiked.toggle()
        }
    }
    
    // MARK: - Platform Linking & Switching
    
    public func selectSource(_ source: MediaSource) {
        self.preferredSource = source
        self.activeSource = source
        UserDefaults.standard.set(source.rawValue, forKey: preferredSourceKey)
        
        // Launch or bring platform app to focus if native
        switch source {
        case .spotify:
            _ = runAppleScript("tell application \"Spotify\" to activate")
        case .appleMusic:
            _ = runAppleScript("tell application \"Music\" to activate")
        case .youtubeMusic:
            openYouTubeMusic()
        default:
            break
        }
        
        refreshPlaylists()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.refreshState()
        }
    }
    
    public func openYouTubeMusic() {
        if let url = URL(string: "https://music.youtube.com") {
            NSWorkspace.shared.open(url)
        }
    }
    
    public func updatePlatformStatus() {
        updatePlatformStatusSync()
    }
    
    private func updatePlatformStatusSync() {
        let ws = NSWorkspace.shared
        let runningApps = ws.runningApplications.compactMap { $0.localizedName?.lowercased() }
        
        let isSpotifyRunning = runningApps.contains { $0.contains("spotify") }
        let isAppleMusicRunning = runningApps.contains { $0 == "music" || $0 == "apple music" }
        let isYTMusicRunning = runningApps.contains { $0.contains("youtube music") }
        
        let spotifyInstalled = ws.urlForApplication(withBundleIdentifier: "com.spotify.client") != nil
        let musicInstalled = ws.urlForApplication(withBundleIdentifier: "com.apple.Music") != nil
        
        let platformList: [MediaPlatformInfo] = [
            MediaPlatformInfo(
                source: .spotify,
                isLinked: true,
                isAppRunning: isSpotifyRunning,
                isAppInstalled: spotifyInstalled,
                accountName: isSpotifyRunning ? "Spotify Premium" : "Spotify App"
            ),
            MediaPlatformInfo(
                source: .appleMusic,
                isLinked: true,
                isAppRunning: isAppleMusicRunning,
                isAppInstalled: musicInstalled,
                accountName: isAppleMusicRunning ? "Apple Music Library" : "Music.app"
            ),
            MediaPlatformInfo(
                source: .youtubeMusic,
                isLinked: true,
                isAppRunning: isYTMusicRunning,
                isAppInstalled: true,
                accountName: "YouTube Music Web/App"
            ),
            MediaPlatformInfo(
                source: .tidal,
                isLinked: false,
                isAppRunning: false,
                isAppInstalled: false,
                accountName: "Tidal HiFi"
            ),
            MediaPlatformInfo(
                source: .soundCloud,
                isLinked: false,
                isAppRunning: false,
                isAppInstalled: false,
                accountName: "SoundCloud"
            ),
            MediaPlatformInfo(
                source: .system,
                isLinked: true,
                isAppRunning: true,
                isAppInstalled: true,
                accountName: "macOS System Audio"
            )
        ]
        
        if Thread.isMainThread {
            self.platforms = platformList
        } else {
            DispatchQueue.main.async {
                self.platforms = platformList
            }
        }
    }
    
    // MARK: - Playlists & Song Selection
    
    public func refreshPlaylists() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let currentActive = self.activeSource != .none ? self.activeSource : (self.preferredSource != .none ? self.preferredSource : .spotify)
            var loadedPlaylists: [MediaPlaylist] = []
            
            // 1. User's saved / custom account playlists for the ACTIVE platform only
            let platformCustom = self.customPlaylists.filter { $0.source == currentActive }
            loadedPlaylists.append(contentsOf: platformCustom)
            
            // 2. Real user playlists from the active platform
            if currentActive == .spotify {
                let spotifyPlaylists = self.fetchSpotifyPlaylists()
                loadedPlaylists.append(contentsOf: spotifyPlaylists)
            } else if currentActive == .appleMusic {
                let musicPlaylists = self.fetchAppleMusicPlaylists()
                loadedPlaylists.append(contentsOf: musicPlaylists)
            } else if currentActive == .youtubeMusic {
                let ytmPlaylists = self.fetchYouTubeMusicPlaylists()
                loadedPlaylists.append(contentsOf: ytmPlaylists)
            }
            
            // 3. User's Liked / Favorited Songs for the active platform
            let likedItems = self.likedTrackIDs.compactMap { id -> MediaTrackItem? in
                let parts = id.components(separatedBy: ":")
                guard parts.count >= 3 else { return nil }
                let source = MediaSource(rawValue: parts[0]) ?? .spotify
                guard source == currentActive else { return nil }
                return MediaTrackItem(
                    title: parts[1],
                    artist: parts[2],
                    durationFormatted: "Favorite",
                    uri: id,
                    source: source
                )
            }
            if !likedItems.isEmpty {
                let likedPlaylist = MediaPlaylist(
                    id: "user_liked_songs_\(currentActive.rawValue)",
                    name: "Liked Songs",
                    description: "Your favorited \(currentActive.shortName) songs",
                    source: currentActive,
                    trackCount: likedItems.count,
                    tracks: likedItems
                )
                loadedPlaylists.insert(likedPlaylist, at: 0)
            }
            
            // 4. Current active track album / context if matching active platform
            if let track = self.currentTrack, track.source == currentActive, !track.album.isEmpty && track.album != "Master Dock Controller" && track.album != "YouTube Music Stream" && track.album != "Web Audio Stream" {
                if !loadedPlaylists.contains(where: { $0.name.localizedCaseInsensitiveCompare(track.album) == .orderedSame }) {
                    let activeAlbumItem = MediaTrackItem(
                        title: track.title,
                        artist: track.artist,
                        album: track.album,
                        durationFormatted: track.formattedDuration,
                        uri: track.trackId ?? "",
                        source: currentActive
                    )
                    let currentAlbumPlaylist = MediaPlaylist(
                        id: "current_playing_album_\(track.album)",
                        name: track.album,
                        description: "\(track.artist) • Album",
                        source: currentActive,
                        trackCount: 1,
                        uri: track.trackId,
                        tracks: [activeAlbumItem]
                    )
                    loadedPlaylists.append(currentAlbumPlaylist)
                }
            }
            
            DispatchQueue.main.async {
                self.playlists = loadedPlaylists
            }
        }
    }
    
    private func fetchSpotifyPlaylists() -> [MediaPlaylist] {
        let fileManager = FileManager.default
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let spotifyDir = homeDir.appendingPathComponent("Library/Application Support/Spotify")
        let spotifyUsersDir = spotifyDir.appendingPathComponent("PersistentCache/Users")
        
        // Discover current Spotify username
        var currentUsername = "of6v8ksqvk2ddq2yub9y8l6bo"
        let prefsFile = spotifyDir.appendingPathComponent("prefs")
        if let prefsContent = try? String(contentsOf: prefsFile, encoding: .utf8) {
            for line in prefsContent.components(separatedBy: "\n") {
                if line.hasPrefix("autologin.canonical_username=") || line.hasPrefix("autologin.username=") {
                    let val = line.components(separatedBy: "=").dropFirst().joined(separator: "=")
                        .trimmingCharacters(in: CharacterSet(charactersIn: "\" \r\n"))
                    if !val.isEmpty {
                        currentUsername = val
                        break
                    }
                }
            }
        }
        
        guard let userFolders = try? fileManager.contentsOfDirectory(at: spotifyUsersDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
            return []
        }
        
        var userPlaylistsMap: [String: String] = [:]
        let usernameBytes = Array(currentUsername.utf8)
        
        for userFolder in userFolders {
            let primaryLdbDir = userFolder.appendingPathComponent("primary.ldb")
            guard let ldbFiles = try? fileManager.contentsOfDirectory(at: primaryLdbDir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else {
                continue
            }
            
            for file in ldbFiles {
                guard let data = try? Data(contentsOf: file) else { continue }
                data.withUnsafeBytes { rawBuffer in
                    guard let baseAddress = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                    let totalBytes = rawBuffer.count
                    var index = 0
                    
                    let attrPrefix = Array("!pl#attr#".utf8)
                    let spotifyPlaylistPrefix = Array("spotify:playlist:".utf8)
                    
                    while index + 40 < totalBytes {
                        // Look for !pl#attr#
                        var foundPrefix = true
                        for i in 0..<attrPrefix.count {
                            if baseAddress[index + i] != attrPrefix[i] {
                                foundPrefix = false
                                break
                            }
                        }
                        
                        if foundPrefix {
                            var searchPos = index + attrPrefix.count
                            if searchPos < totalBytes && baseAddress[searchPos] == UInt8(ascii: "'") {
                                searchPos += 1
                            }
                            
                            var foundPl = true
                            for i in 0..<spotifyPlaylistPrefix.count {
                                if searchPos + i >= totalBytes || baseAddress[searchPos + i] != spotifyPlaylistPrefix[i] {
                                    foundPl = false
                                    break
                                }
                            }
                            
                            if foundPl {
                                let idStart = searchPos + spotifyPlaylistPrefix.count
                                if idStart + 22 <= totalBytes {
                                    let idData = Data(bytes: baseAddress + idStart, count: 22)
                                    if let playlistID = String(data: idData, encoding: .utf8),
                                       !playlistID.hasPrefix("37i9dQ"), // Exclude Spotify algorithmic and radio mixes
                                       playlistID.range(of: "^[a-zA-Z0-9]{22}$", options: .regularExpression) != nil {
                                        
                                        let chunkLimit = min(totalBytes, idStart + 22 + 250)
                                        var p = idStart + 22
                                        var foundName: String? = nil
                                        
                                        while p + 2 < chunkLimit {
                                            if baseAddress[p] == 0x0A { // \n tag 1, wire type 2
                                                let len = Int(baseAddress[p + 1])
                                                if len > 0 && len < 80 && p + 2 + len <= chunkLimit {
                                                    let nameData = Data(bytes: baseAddress + p + 2, count: len)
                                                    if let parsed = String(data: nameData, encoding: .utf8), !parsed.isEmpty {
                                                        let clean = parsed.trimmingCharacters(in: .whitespacesAndNewlines)
                                                        if !clean.isEmpty && !clean.hasPrefix("spotify:") && !clean.hasPrefix("VIDEOS_DISABLED") && clean != "xmeta" && clean != "cinfo" && !clean.contains("\t") {
                                                            foundName = clean
                                                            break
                                                        }
                                                    }
                                                }
                                            }
                                            p += 1
                                        }
                                        
                                        if let name = foundName {
                                            // Ensure this playlist belongs to the user's library
                                            let checkEnd = min(totalBytes, idStart + 22 + 250)
                                            let checkCount = checkEnd - (idStart + 22)
                                            var isOwnedByUser = false
                                            
                                            if checkCount >= usernameBytes.count {
                                                for k in 0...(checkCount - usernameBytes.count) {
                                                    var match = true
                                                    for u in 0..<usernameBytes.count {
                                                        if baseAddress[idStart + 22 + k + u] != usernameBytes[u] {
                                                            match = false
                                                            break
                                                        }
                                                    }
                                                    if match {
                                                        isOwnedByUser = true
                                                        break
                                                    }
                                                }
                                            }
                                            
                                            if isOwnedByUser {
                                                userPlaylistsMap[playlistID] = name
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        index += 1
                    }
                }
            }
        }
        
        let sorted = userPlaylistsMap.sorted { a, b in
            a.value.localizedCaseInsensitiveCompare(b.value) == .orderedAscending
        }
        
        return sorted.map { pid, name in
            MediaPlaylist(
                id: "spotify:playlist:\(pid)",
                name: name,
                description: "Spotify User Playlist",
                source: .spotify,
                trackCount: 0,
                uri: "spotify:playlist:\(pid)",
                tracks: []
            )
        }
    }
    
    private func fetchAppleMusicPlaylists() -> [MediaPlaylist] {
        let script = """
        if application "Music" is running then
            tell application "Music"
                try
                    set pNames to name of user playlists
                    set output to ""
                    repeat with pName in pNames
                        set output to output & pName & "---"
                    end repeat
                    return output
                on error
                    try
                        set pNames to name of playlists
                        set output to ""
                        repeat with pName in pNames
                            set output to output & pName & "---"
                        end repeat
                        return output
                    end try
                end try
            end tell
        end if
        return ""
        """
        
        guard let output = runAppleScript(script), !output.isEmpty else { return [] }
        let names = output.components(separatedBy: "---").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty && $0 != "Music" && $0 != "Downloaded" && $0 != "Library" }
        
        return names.map { name in
            MediaPlaylist(
                id: "apple_music_playlist_\(name)",
                name: name,
                description: "Apple Music Playlist",
                source: .appleMusic,
                trackCount: 0,
                uri: name,
                tracks: []
            )
        }
    }
    
    private func fetchYouTubeMusicPlaylists() -> [MediaPlaylist] {
        var list: [MediaPlaylist] = []
        list.append(
            MediaPlaylist(
                id: "ytm_liked_music",
                name: "Liked Music",
                description: "YouTube Music Library",
                source: .youtubeMusic,
                trackCount: 0,
                uri: "https://music.youtube.com/playlist?list=LM",
                tracks: []
            )
        )
        list.append(
            MediaPlaylist(
                id: "ytm_my_mix",
                name: "My Supermix",
                description: "YouTube Music Endless Mix",
                source: .youtubeMusic,
                trackCount: 0,
                uri: "https://music.youtube.com/playlist?list=RDTMAK5uy_kset8DisdE7LSD4TNjEVvrKRTmG7a56sY",
                tracks: []
            )
        )
        return list
    }
    
    private func fetchTracksForAppleMusicPlaylist(_ playlistName: String) -> [MediaTrackItem] {
        let script = """
        if application "Music" is running then
            tell application "Music"
                try
                    set targetPlaylist to user playlist "\(playlistName)"
                    set tNames to name of tracks of targetPlaylist
                    set tArtists to artist of tracks of targetPlaylist
                    set tTimes to time of tracks of targetPlaylist
                    set output to ""
                    repeat with i from 1 to count of tNames
                        if i > 50 then exit repeat
                        set output to output & (item i of tNames) & "|||" & (item i of tArtists) & "|||" & (item i of tTimes) & "---"
                    end repeat
                    return output
                end try
            end tell
        end if
        return ""
        """
        
        guard let output = runAppleScript(script), !output.isEmpty else { return [] }
        
        let rows = output.components(separatedBy: "---").filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        var result: [MediaTrackItem] = []
        
        for row in rows {
            let parts = row.components(separatedBy: "|||")
            if parts.count >= 2 {
                result.append(
                    MediaTrackItem(
                        title: parts[0],
                        artist: parts[1],
                        durationFormatted: parts.count > 2 ? parts[2] : "3:30",
                        uri: playlistName,
                        source: .appleMusic
                    )
                )
            }
        }
        
        return result
    }
    
    public func playPlaylist(_ playlist: MediaPlaylist) {
        switch playlist.source {
        case .spotify:
            if let uri = playlist.uri, !uri.isEmpty {
                if uri.hasPrefix("spotify:") {
                    _ = runAppleScript("tell application \"Spotify\" to play track \"\" in context \"\(uri)\"")
                } else if let url = URL(string: uri) {
                    NSWorkspace.shared.open(url)
                }
            } else {
                _ = runAppleScript("tell application \"Spotify\" to play")
            }
        case .appleMusic:
            if let name = playlist.uri, !name.isEmpty {
                _ = runAppleScript("tell application \"Music\" to play playlist \"\(name)\"")
            } else {
                _ = runAppleScript("tell application \"Music\" to play")
            }
        case .youtubeMusic:
            if let uri = playlist.uri, let url = URL(string: uri) {
                NSWorkspace.shared.open(url)
            } else {
                openYouTubeMusic()
            }
        default:
            sendSystemMediaKey(key: 16)
        }
        
        self.activeSource = playlist.source
        self.isPlaying = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.refreshState()
        }
    }
    
    public func searchSongs(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            self.searchResults = []
            self.isSearchingSongs = false
            self.searchTask?.cancel()
            self.searchTask = nil
            return
        }
        
        self.isSearchingSongs = true
        self.searchTask?.cancel()
        
        let currentSource = self.activeSource
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=15") else {
            self.isSearchingSongs = false
            return
        }
        
        self.searchTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            guard let self = self else { return }
            if let error = error as NSError?, error.code == NSURLErrorCancelled {
                return
            }
            
            var items: [MediaTrackItem] = []
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]] {
                for r in results {
                    let trackName = r["trackName"] as? String ?? ""
                    let artistName = r["artistName"] as? String ?? ""
                    let albumName = r["collectionName"] as? String ?? ""
                    let trackId = (r["trackId"] as? Int).map { String($0) } ?? UUID().uuidString
                    let millis = r["trackTimeMillis"] as? Double ?? 0.0
                    let artUrlStr = (r["artworkUrl100"] as? String) ?? (r["artworkUrl60"] as? String)
                    let artURL = artUrlStr.flatMap { URL(string: $0) }
                    
                    let mins = Int(millis / 1000) / 60
                    let secs = Int(millis / 1000) % 60
                    let durStr = String(format: "%d:%02d", mins, secs)
                    
                    if !trackName.isEmpty {
                        items.append(
                            MediaTrackItem(
                                id: trackId,
                                title: trackName,
                                artist: artistName,
                                album: albumName,
                                durationFormatted: durStr,
                                uri: "\(trackName) \(artistName)",
                                source: currentSource,
                                artworkURL: artURL
                            )
                        )
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.searchResults = items
                self.isSearchingSongs = false
            }
        }
        
        self.searchTask?.resume()
    }
    
    public func playTrackItem(_ item: MediaTrackItem) {
        let searchTerm = "\(item.title) \(item.artist)".trimmingCharacters(in: .whitespacesAndNewlines)
        switch activeSource {
        case .spotify:
            if item.uri.hasPrefix("spotify:track:") {
                _ = runAppleScript("tell application \"Spotify\" to play track \"\(item.uri)\"")
            } else {
                let script = """
                tell application "Spotify"
                    try
                        play track "" in context "spotify:search:\(searchTerm)"
                    on error
                        open location "spotify:search:\(searchTerm)"
                    end try
                end tell
                """
                _ = runAppleScript(script)
            }
        case .appleMusic:
            let script = """
            tell application "Music"
                try
                    play (first track whose name contains "\(item.title)")
                on error
                    open location "music://music.apple.com/search?term=\(searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")"
                end try
            end tell
            """
            _ = runAppleScript(script)
        case .youtubeMusic:
            let query = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "https://music.youtube.com/search?q=\(query)") {
                NSWorkspace.shared.open(url)
            }
        default:
            sendSystemMediaKey(key: 16)
        }
        
        self.isPlaying = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            self.refreshState()
        }
    }
    
    public func searchAndPlaySong(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        switch self.activeSource {
        case .spotify:
            let script = """
            tell application "Spotify"
                play track "" in context "spotify:search:\(trimmed)"
            end tell
            """
            _ = runAppleScript(script)
            self.isPlaying = true
        case .appleMusic:
            let script = """
            tell application "Music"
                try
                    play (first track whose name contains "\(trimmed)" or artist contains "\(trimmed)")
                end try
            end tell
            """
            _ = runAppleScript(script)
            self.isPlaying = true
        case .youtubeMusic:
            let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let url = URL(string: "https://music.youtube.com/search?q=\(encoded)") {
                NSWorkspace.shared.open(url)
            }
            self.isPlaying = true
        default:
            let script = """
            tell application "Spotify"
                play track "" in context "spotify:search:\(trimmed)"
            end tell
            """
            _ = runAppleScript(script)
            self.isPlaying = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.refreshState()
        }
    }
    
    public func addCustomPlaylist(name: String, description: String, source: MediaSource, uri: String) {
        let newPlaylist = MediaPlaylist(
            name: name,
            description: description,
            source: source,
            trackCount: 1,
            uri: uri,
            tracks: [
                MediaTrackItem(title: name, artist: source.rawValue, durationFormatted: "--:--", uri: uri, source: source)
            ]
        )
        customPlaylists.append(newPlaylist)
        persistCustomPlaylists()
        refreshPlaylists()
    }
    
    public func removeCustomPlaylist(id: String) {
        customPlaylists.removeAll { $0.id == id }
        persistCustomPlaylists()
        refreshPlaylists()
    }
    
    // MARK: - Browser & YouTube Music Automation
    
    private func controlYouTubeMusicPlayback(action: String, value: Double = 0.0) {
        let script: String
        switch action {
        case "playpause":
            script = """
            if application "Google Chrome" is running then
                tell application "Google Chrome"
                    repeat with w in windows
                        repeat with t in tabs of w
                            if URL of t contains "music.youtube.com" then
                                execute t javascript "document.querySelector('#play-pause-button')?.click() || document.querySelector('video')?.paused ? document.querySelector('video')?.play() : document.querySelector('video')?.pause();"
                                return "OK"
                            end if
                        end repeat
                    end repeat
                end tell
            end if
            """
        case "next":
            script = """
            if application "Google Chrome" is running then
                tell application "Google Chrome"
                    repeat with w in windows
                        repeat with t in tabs of w
                            if URL of t contains "music.youtube.com" then
                                execute t javascript "document.querySelector('.next-button')?.click();"
                                return "OK"
                            end if
                        end repeat
                    end repeat
                end tell
            end if
            """
        case "previous":
            script = """
            if application "Google Chrome" is running then
                tell application "Google Chrome"
                    repeat with w in windows
                        repeat with t in tabs of w
                            if URL of t contains "music.youtube.com" then
                                execute t javascript "document.querySelector('.previous-button')?.click();"
                                return "OK"
                            end if
                        end repeat
                    end repeat
                end tell
            end if
            """
        case "seek":
            script = """
            if application "Google Chrome" is running then
                tell application "Google Chrome"
                    repeat with w in windows
                        repeat with t in tabs of w
                            if URL of t contains "music.youtube.com" then
                                execute t javascript "let v = document.querySelector('video'); if (v) { v.currentTime = \(value); }"
                                return "OK"
                            end if
                        end repeat
                    end repeat
                end tell
            end if
            """
        case "repeat":
            script = """
            if application "Google Chrome" is running then
                tell application "Google Chrome"
                    repeat with w in windows
                        repeat with t in tabs of w
                            if URL of t contains "music.youtube.com" then
                                execute t javascript "let repBtn = document.querySelector('.repeat'); if(repBtn) repBtn.click(); let v = document.querySelector('video'); if(v) v.loop = \(value == 1.0 ? "true" : "false");"
                                return "OK"
                            end if
                        end repeat
                    end repeat
                end tell
            end if
            """
        default:
            script = ""
        }
        
        if !script.isEmpty {
            _ = runAppleScript(script)
        }
    }
    
    // MARK: - Persistence & Helpers
    
    private func loadPersistedData() {
        if let preferredRaw = UserDefaults.standard.string(forKey: preferredSourceKey),
           let source = MediaSource(rawValue: preferredRaw) {
            self.preferredSource = source
            self.activeSource = source
        }
        
        if let likedArray = UserDefaults.standard.stringArray(forKey: likedTracksKey) {
            self.likedTrackIDs = Set(likedArray)
        }
        
        if let data = UserDefaults.standard.data(forKey: customPlaylistsKey),
           let decoded = try? JSONDecoder().decode([SavedCustomPlaylist].self, from: data) {
            self.customPlaylists = decoded.map { $0.toMediaPlaylist() }
        }
    }
    
    private func persistLikedTracks() {
        UserDefaults.standard.set(Array(likedTrackIDs), forKey: likedTracksKey)
    }
    
    private func persistCustomPlaylists() {
        let items = customPlaylists.map { SavedCustomPlaylist(from: $0) }
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: customPlaylistsKey)
        }
    }
    
    private func loadDefaultPlaylists() {
        refreshPlaylists()
    }
    
    @discardableResult
    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: source) {
            let output = scriptObject.executeAndReturnError(&error)
            if error == nil {
                return output.stringValue
            }
        }
        return nil
    }
    
    private func sendSystemMediaKey(key: Int32) {
        func postKey(down: Bool) {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xa00 : 0xb00)
            let data1 = Int((key << 16) | (down ? 0xa00 : 0xb00))
            let ev = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            if let cgev = ev?.cgEvent {
                cgev.post(tap: .cghidEventTap)
            }
        }
        postKey(down: true)
        postKey(down: false)
    }
}

/// Helper codable struct for persisting custom user playlists in UserDefaults
private struct SavedCustomPlaylist: Codable {
    let id: String
    let name: String
    let description: String
    let sourceRaw: String
    let trackCount: Int
    let uri: String?
    
    init(from playlist: MediaPlaylist) {
        self.id = playlist.id
        self.name = playlist.name
        self.description = playlist.description
        self.sourceRaw = playlist.source.rawValue
        self.trackCount = playlist.trackCount
        self.uri = playlist.uri
    }
    
    func toMediaPlaylist() -> MediaPlaylist {
        let source = MediaSource(rawValue: sourceRaw) ?? .spotify
        return MediaPlaylist(
            id: id,
            name: name,
            description: description,
            source: source,
            trackCount: trackCount,
            artworkURL: nil,
            uri: uri,
            tracks: [
                MediaTrackItem(title: name, artist: source.rawValue, durationFormatted: "--:--", uri: uri ?? "", source: source)
            ]
        )
    }
}
