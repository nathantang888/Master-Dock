import Foundation
import AppKit
import SwiftUI

/// Supported music and media streaming platforms
public enum MediaSource: String, Codable, CaseIterable, Identifiable, Sendable {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case youtubeMusic = "YouTube Music"
    case tidal = "Tidal"
    case soundCloud = "SoundCloud"
    case webMedia = "Web Player"
    case system = "System Audio"
    case none = "None"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .appleMusic: return "music.note"
        case .spotify: return "antenna.radiowaves.left.and.right"
        case .youtubeMusic: return "play.rectangle.fill"
        case .tidal: return "waveform"
        case .soundCloud: return "cloud.fill"
        case .webMedia: return "globe"
        case .system: return "speaker.wave.2.fill"
        case .none: return "music.quarternote.3"
        }
    }
    
    public var shortName: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        case .youtubeMusic: return "YouTube Music"
        case .tidal: return "Tidal"
        case .soundCloud: return "SoundCloud"
        case .webMedia: return "Web"
        case .system: return "System"
        case .none: return "None"
        }
    }
    
    public var brandAccentColor: Color {
        switch self {
        case .appleMusic: return Color(red: 0.98, green: 0.24, blue: 0.35) // Apple Music vibrant red-pink
        case .spotify: return Color(red: 0.11, green: 0.73, blue: 0.33)    // Spotify green
        case .youtubeMusic: return Color(red: 1.00, green: 0.15, blue: 0.15) // YouTube Red
        case .tidal: return Color(red: 0.00, green: 0.85, blue: 0.95)       // Cyan
        case .soundCloud: return Color(red: 1.00, green: 0.45, blue: 0.00)  // Orange
        case .webMedia: return Color(red: 0.35, green: 0.65, blue: 1.00)    // Blue
        case .system: return Color(red: 0.60, green: 0.60, blue: 0.65)      // Slate
        case .none: return Color.gray
        }
    }
}

/// Playback repeat options
public enum RepeatMode: String, Codable, CaseIterable, Sendable {
    case off = "Off"
    case all = "All"
    case one = "One"
    
    public var iconName: String {
        switch self {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }
}

/// Represents the currently playing or active track with metadata and timeline
public struct MediaTrack: Equatable, Sendable, Identifiable {
    public var id: String { "\(source.rawValue):\(title):\(artist)" }
    public let title: String
    public let artist: String
    public let album: String
    public let duration: Double // In seconds
    public let position: Double // In seconds
    public let artworkData: Data?
    public let artworkURL: URL?
    public let isPlaying: Bool
    public let isLiked: Bool
    public let source: MediaSource
    public let trackId: String?
    
    public init(
        title: String,
        artist: String,
        album: String = "",
        duration: Double = 0.0,
        position: Double = 0.0,
        artworkData: Data? = nil,
        artworkURL: URL? = nil,
        isPlaying: Bool = false,
        isLiked: Bool = false,
        source: MediaSource = .none,
        trackId: String? = nil
    ) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.position = position
        self.artworkData = artworkData
        self.artworkURL = artworkURL
        self.isPlaying = isPlaying
        self.isLiked = isLiked
        self.source = source
        self.trackId = trackId
    }
    
    public var progressRatio: Double {
        guard duration > 0 else { return 0.0 }
        return min(max(0.0, position / duration), 1.0)
    }
    
    public var formattedPosition: String {
        formatTime(seconds: position)
    }
    
    public var formattedDuration: String {
        formatTime(seconds: duration)
    }
    
    private func formatTime(seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

/// Represents an individual song item in a playlist or library
public struct MediaTrackItem: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String
    public let durationFormatted: String
    public let uri: String
    public let source: MediaSource
    public let artworkURL: URL?
    
    public init(
        id: String = UUID().uuidString,
        title: String,
        artist: String,
        album: String = "",
        durationFormatted: String = "",
        uri: String = "",
        source: MediaSource,
        artworkURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.durationFormatted = durationFormatted
        self.uri = uri
        self.source = source
        self.artworkURL = artworkURL
    }
}

/// Represents a playlist or album container from any platform
public struct MediaPlaylist: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let description: String
    public let source: MediaSource
    public let trackCount: Int
    public let artworkURL: URL?
    public let uri: String?
    public var tracks: [MediaTrackItem]
    
    public init(
        id: String = UUID().uuidString,
        name: String,
        description: String = "",
        source: MediaSource,
        trackCount: Int = 0,
        artworkURL: URL? = nil,
        uri: String? = nil,
        tracks: [MediaTrackItem] = []
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.source = source
        self.trackCount = trackCount > 0 ? trackCount : tracks.count
        self.artworkURL = artworkURL
        self.uri = uri
        self.tracks = tracks
    }
}

/// Represents connection & link status for a music service
public struct MediaPlatformInfo: Identifiable, Equatable, Sendable {
    public var id: String { source.rawValue }
    public let source: MediaSource
    public var isLinked: Bool
    public var isAppRunning: Bool
    public var isAppInstalled: Bool
    public var accountName: String?
    
    public init(
        source: MediaSource,
        isLinked: Bool = false,
        isAppRunning: Bool = false,
        isAppInstalled: Bool = false,
        accountName: String? = nil
    ) {
        self.source = source
        self.isLinked = isLinked
        self.isAppRunning = isAppRunning
        self.isAppInstalled = isAppInstalled
        self.accountName = accountName
    }
}
