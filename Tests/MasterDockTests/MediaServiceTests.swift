import Foundation
import SwiftUI
import MasterDockCore
import MasterDockServices

final class MediaServiceTests {
    
    func testMediaSourceProperties() {
        let sources: [MediaSource] = [.appleMusic, .spotify, .youtubeMusic, .tidal, .soundCloud, .webMedia, .system]
        for src in sources {
            XCTAssertFalse(src.rawValue.isEmpty, "Source rawValue should not be empty")
            XCTAssertFalse(src.iconName.isEmpty, "Source iconName should not be empty")
            XCTAssertFalse(src.shortName.isEmpty, "Source shortName should not be empty")
        }
        
        XCTAssertEqual(MediaSource.spotify.shortName, "Spotify")
        XCTAssertEqual(MediaSource.appleMusic.shortName, "Apple Music")
        XCTAssertEqual(MediaSource.youtubeMusic.shortName, "YouTube Music")
    }
    
    func testMediaTrackFormatting() {
        let track = MediaTrack(
            title: "Midnight City",
            artist: "M83",
            album: "Hurry Up, We're Dreaming",
            duration: 243.0, // 4:03
            position: 65.0,  // 1:05
            isPlaying: true,
            isLiked: false,
            source: .spotify
        )
        
        XCTAssertEqual(track.title, "Midnight City")
        XCTAssertEqual(track.artist, "M83")
        XCTAssertEqual(track.formattedPosition, "1:05")
        XCTAssertEqual(track.formattedDuration, "4:03")
        
        let expectedRatio = 65.0 / 243.0
        XCTAssertTrue(abs(track.progressRatio - expectedRatio) < 0.001, "Progress ratio calculation mismatch")
    }
    
    func testMediaPlaylistAndTracks() {
        let track1 = MediaTrackItem(
            title: "Espresso",
            artist: "Sabrina Carpenter",
            album: "Short n' Sweet",
            durationFormatted: "2:55",
            uri: "spotify:track:123",
            source: .spotify
        )
        
        let track2 = MediaTrackItem(
            title: "Birds of a Feather",
            artist: "Billie Eilish",
            album: "HIT ME HARD AND SOFT",
            durationFormatted: "3:30",
            uri: "spotify:track:456",
            source: .spotify
        )
        
        let playlist = MediaPlaylist(
            name: "Today's Top Hits",
            description: "Hottest songs",
            source: .spotify,
            trackCount: 2,
            tracks: [track1, track2]
        )
        
        XCTAssertEqual(playlist.name, "Today's Top Hits")
        XCTAssertEqual(playlist.tracks.count, 2)
        XCTAssertEqual(playlist.tracks[0].title, "Espresso")
        XCTAssertEqual(playlist.tracks[1].artist, "Billie Eilish")
    }
    
    func testPlaybackControlsMath() {
        let service = MediaService.shared
        service.seek(to: 30.0)
        XCTAssertEqual(service.playbackPosition, 30.0)
        
        // Rewind 15s -> 15.0
        service.rewind(seconds: 15.0)
        XCTAssertEqual(service.playbackPosition, 15.0)
        
        // Rewind 20s -> Clamped to 0.0
        service.rewind(seconds: 20.0)
        XCTAssertEqual(service.playbackPosition, 0.0)
        
        // Fast-Forward 15s -> 15.0
        service.fastForward(seconds: 15.0)
        XCTAssertEqual(service.playbackPosition, 15.0)
    }
    
    func testVolumeClamping() {
        let service = MediaService.shared
        service.setVolume(0.5)
        XCTAssertEqual(service.volume, 0.5)
        
        service.setVolume(1.5) // Exceeds upper bound
        XCTAssertEqual(service.volume, 1.0)
        
        service.setVolume(-0.2) // Below lower bound
        XCTAssertEqual(service.volume, 0.0)
        
        service.setVolume(0.8)
        XCTAssertEqual(service.volume, 0.8)
    }
    
    func testShuffleAndRepeatCycling() {
        let service = MediaService.shared
        let initialShuffle = service.isShuffleEnabled
        service.toggleShuffle()
        XCTAssertEqual(service.isShuffleEnabled, !initialShuffle)
        service.toggleShuffle()
        XCTAssertEqual(service.isShuffleEnabled, initialShuffle)
        
        // Test Repeat Cycling: Off -> All -> One -> Off
        if service.repeatMode != .off {
            while service.repeatMode != .off {
                service.cycleRepeatMode()
            }
        }
        XCTAssertEqual(service.repeatMode, .off)
        service.cycleRepeatMode()
        XCTAssertEqual(service.repeatMode, .all)
        service.cycleRepeatMode()
        XCTAssertEqual(service.repeatMode, .one)
        service.cycleRepeatMode()
        XCTAssertEqual(service.repeatMode, .off)
    }
    
    func testLikedTracks() {
        let service = MediaService.shared
        let initialLiked = service.isLiked
        service.toggleLiked()
        XCTAssertEqual(service.isLiked, !initialLiked)
        service.toggleLiked()
        XCTAssertEqual(service.isLiked, initialLiked)
    }
    
    func testCustomPlaylists() {
        let service = MediaService.shared
        let initialCount = service.customPlaylists.count
        let customName = "My Synthwave Mix"
        
        service.addCustomPlaylist(
            name: customName,
            description: "80s Retro",
            source: .spotify,
            uri: "spotify:playlist:test12345"
        )
        
        XCTAssertEqual(service.customPlaylists.count, initialCount + 1)
        if let added = service.customPlaylists.first(where: { $0.name == customName }) {
            XCTAssertEqual(added.source, .spotify)
            service.removeCustomPlaylist(id: added.id)
            XCTAssertEqual(service.customPlaylists.count, initialCount)
        }
    }
    
    func testPlatformInformation() {
        let service = MediaService.shared
        service.updatePlatformStatus()
        
        XCTAssertFalse(service.platforms.isEmpty)
        let sources = service.platforms.map { $0.source }
        XCTAssertTrue(sources.contains(.spotify))
        XCTAssertTrue(sources.contains(.appleMusic))
        XCTAssertTrue(sources.contains(.youtubeMusic))
    }
}
