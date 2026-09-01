import SwiftUI
import AppKit
import MasterDockCore
import MasterDockServices

public struct MediaSectionView: View {
    @ObservedObject public var mediaService: MediaService
    
    // Interactive UI State
    @State private var isLibraryExpanded: Bool = false
    @State private var searchQuery: String = ""
    @State private var isDraggingScrubber: Bool = false
    @State private var scrubbedPosition: Double = 0.0
    @State private var isVolumeHovered: Bool = false
    
    public init(mediaService: MediaService) {
        self.mediaService = mediaService
    }
    
    private var currentPosition: Double {
        isDraggingScrubber ? scrubbedPosition : mediaService.playbackPosition
    }
    
    private var currentDuration: Double {
        mediaService.trackDuration > 0 ? mediaService.trackDuration : 180.0
    }
    
    private var allSearchableTracks: [MediaTrackItem] {
        var tracks: [MediaTrackItem] = []
        for pl in mediaService.playlists {
            tracks.append(contentsOf: pl.tracks)
        }
        return tracks
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 1. Header (Clean "Media Controller" + Playlist count)
            headerView
            
            // 2. Quick Song Search Bar
            quickSearchBar
            
            // 3. Search Results (Live if typing)
            if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                searchResultsView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // 4. Main Now Playing Glass Card
            nowPlayingCard
            
            // 6. Scrubbable Progress Bar
            playbackProgressBar
            
            // 7. Complete Transport Controls (Shuffle, Prev, Rewind 15s, Play/Pause, Fast-Forward 15s, Next, Repeat)
            transportControlsRow
            
            // 8. Volume & Library Drawer Toggle Bar
            volumeAndDrawerBar
            
            // 9. Expandable Library, Playlist & Song Selection Drawer
            if isLibraryExpanded {
                libraryDrawer
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.8), value: isLibraryExpanded)
        .animation(.easeInOut(duration: 0.2), value: searchQuery)
        .animation(.easeInOut(duration: 0.2), value: mediaService.activeSource)
    }
    
    // MARK: - 1. Header View
    
    private var headerView: some View {
        HStack {
            HStack(spacing: 7) {
                Image(systemName: mediaService.activeSource.iconName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(mediaService.activeSource.brandAccentColor)
                
                Text(mediaService.activeSource.shortName)
                    .font(AppTypography.titleMedium)
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 2. Quick Song Search Bar
    
    private var quickSearchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(searchQuery.isEmpty ? .white.opacity(0.45) : mediaService.activeSource.brandAccentColor)
            
            TextField("Search songs on \(mediaService.activeSource.shortName)...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(AppTypography.caption)
                .foregroundColor(.white)
                .onChange(of: searchQuery) { _, newValue in
                    mediaService.searchSongs(query: newValue)
                }
                .onSubmit {
                    if !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if let firstMatch = mediaService.searchResults.first {
                            mediaService.playTrackItem(firstMatch)
                            searchQuery = ""
                        } else {
                            mediaService.searchAndPlaySong(searchQuery)
                        }
                    }
                }
            
            if mediaService.isSearchingSongs {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: mediaService.activeSource.brandAccentColor))
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
            } else if !searchQuery.isEmpty {
                Button(action: {
                    searchQuery = ""
                    mediaService.searchSongs(query: "")
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .help("Clear Search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(searchQuery.isEmpty ? 0.12 : 0.35), lineWidth: 0.7)
        )
    }
    
    // MARK: - 3. Search Results Overlay View
    
    private var searchResultsView: some View {
        VStack(alignment: .leading, spacing: 6) {
            let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(mediaService.activeSource.brandAccentColor)
                    
                    Text("Search Results on \(mediaService.activeSource.shortName)")
                        .font(AppTypography.micro)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.9))
                }
                
                Spacer()
                
                if mediaService.isSearchingSongs {
                    Text("Searching...")
                        .font(AppTypography.micro)
                        .foregroundColor(.white.opacity(0.45))
                } else if !mediaService.searchResults.isEmpty {
                    Text("\(mediaService.searchResults.count) songs")
                        .font(AppTypography.micro)
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            
            if !mediaService.searchResults.isEmpty {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 4) {
                        ForEach(mediaService.searchResults) { track in
                            SongRow(track: track) {
                                mediaService.playTrackItem(track)
                                searchQuery = ""
                            }
                        }
                    }
                    .background(
                        ScrollEdgeFadeObserver(fadeLength: 16.0, fadeThreshold: 12.0)
                    )
                }
                .frame(maxHeight: 180)
            } else if !mediaService.isSearchingSongs {
                VStack(spacing: 6) {
                    Text("No direct song matches found for '\(query)'")
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Button(action: {
                        mediaService.searchAndPlaySong(query)
                        searchQuery = ""
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 8))
                            Text("Search & Play directly in \(mediaService.activeSource.shortName)")
                                .font(AppTypography.micro)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Capsule().fill(mediaService.activeSource.brandAccentColor))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.6)
        )
    }
    
    // MARK: - 4. Main Now Playing Glass Card
    
    private var nowPlayingCard: some View {
        HStack(spacing: 12) {
            // Album Art with Platform Dynamic Glow
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                mediaService.activeSource.brandAccentColor.opacity(0.85),
                                GlassTheme.accentPurple.opacity(0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                    )
                    .shadow(color: mediaService.activeSource.brandAccentColor.opacity(mediaService.isPlaying ? 0.55 : 0.25), radius: mediaService.isPlaying ? 8 : 4, x: 0, y: 2)
                
                if let track = mediaService.currentTrack, let artworkData = track.artworkData, let nsImage = NSImage(data: artworkData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else if let track = mediaService.currentTrack, let artworkURL = track.artworkURL {
                    AsyncImage(url: artworkURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        case .failure, .empty:
                            AlbumCoverPlaceholder(source: mediaService.activeSource)
                        @unknown default:
                            AlbumCoverPlaceholder(source: mediaService.activeSource)
                        }
                    }
                    .frame(width: 48, height: 48)
                } else {
                    AlbumCoverPlaceholder(source: mediaService.activeSource)
                }
            }
            
            // Track & Artist Info
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(mediaService.currentTrack?.title ?? "No Active Playback")
                        .font(AppTypography.bodyBold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // Like / Favorite Heart Button
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.6)) {
                            mediaService.toggleLiked()
                        }
                    }) {
                        Image(systemName: mediaService.isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(mediaService.isLiked ? GlassTheme.accentRose : .white.opacity(0.45))
                            .scaleEffect(mediaService.isLiked ? 1.15 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .help(mediaService.isLiked ? "Remove from Liked Songs" : "Save to Liked Songs")
                }
                
                HStack(spacing: 4) {
                    Text(mediaService.currentTrack?.artist ?? "\(mediaService.activeSource.shortName)")
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.65))
                        .lineLimit(1)
                    
                    if let album = mediaService.currentTrack?.album, !album.isEmpty && album != "Master Dock Controller" {
                        Text("•")
                            .foregroundColor(.white.opacity(0.3))
                            .font(AppTypography.caption)
                        Text(album)
                            .font(AppTypography.micro)
                            .foregroundColor(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(10)
        .liquidPillStyle(cornerRadius: 14)
    }
    
    // MARK: - 3. Scrubbable Progress Bar
    
    private var playbackProgressBar: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let width = geo.size.width
                let progress = currentDuration > 0 ? max(0.0, min(1.0, currentPosition / currentDuration)) : 0.0
                
                ZStack(alignment: .leading) {
                    // Track Background
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)
                    
                    // Active Fill with Platform Color Gradient
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    mediaService.activeSource.brandAccentColor,
                                    GlassTheme.accentCyan
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, width * CGFloat(progress)), height: 4)
                    
                    // Scrubber Knob
                    Circle()
                        .fill(Color.white)
                        .frame(width: isDraggingScrubber ? 10 : 8, height: isDraggingScrubber ? 10 : 8)
                        .shadow(color: Color.black.opacity(0.4), radius: 2, x: 0, y: 1)
                        .offset(x: max(0, min(width - 8, width * CGFloat(progress) - 4)))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDraggingScrubber = true
                            let ratio = max(0.0, min(1.0, Double(value.location.x / width)))
                            scrubbedPosition = ratio * currentDuration
                        }
                        .onEnded { value in
                            let ratio = max(0.0, min(1.0, Double(value.location.x / width)))
                            let targetSec = ratio * currentDuration
                            mediaService.seek(to: targetSec)
                            isDraggingScrubber = false
                        }
                )
            }
            .frame(height: 8)
            
            // Timestamps
            HStack {
                Text(formatSeconds(currentPosition))
                    .font(AppTypography.micro.monospacedDigit())
                    .foregroundColor(.white.opacity(0.55))
                
                Spacer()
                
                Text(formatSeconds(currentDuration))
                    .font(AppTypography.micro.monospacedDigit())
                    .foregroundColor(.white.opacity(0.55))
            }
            .padding(.horizontal, 2)
        }
        .padding(.horizontal, 4)
    }
    
    // MARK: - 4. Transport Controls Row
    
    private var transportControlsRow: some View {
        HStack(spacing: 8) {
            // Shuffle
            GlassIconButton(
                iconSystemName: "shuffle",
                size: 28,
                iconSize: 11,
                accentColor: mediaService.isShuffleEnabled ? mediaService.activeSource.brandAccentColor : nil,
                helpText: mediaService.isShuffleEnabled ? "Shuffle: On" : "Shuffle: Off",
                action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        mediaService.toggleShuffle()
                    }
                }
            )
            
            Spacer()
            
            // Previous Track
            GlassIconButton(
                iconSystemName: "backward.fill",
                size: 28,
                iconSize: 12,
                helpText: "Previous Track",
                action: { mediaService.previousTrack() }
            )
            
            // Rewind 15s
            GlassIconButton(
                iconSystemName: "gobackward.15",
                size: 30,
                iconSize: 12,
                helpText: "Rewind 15 Seconds",
                action: { mediaService.rewind(seconds: 15) }
            )
            
            // Play / Pause Main Button
            Button(action: { mediaService.playPause() }) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    mediaService.activeSource.brandAccentColor,
                                    GlassTheme.accentBlue
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    Circle()
                        .fill(GlassTheme.liquidGlassSheen)
                    
                    Image(systemName: mediaService.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
                .frame(width: 38, height: 38)
                .overlay(Circle().strokeBorder(GlassTheme.liquidSpecularBorder, lineWidth: 0.85))
                .vibrantGlow(color: mediaService.activeSource.brandAccentColor, radius: 6)
            }
            .buttonStyle(.plain)
            .help(mediaService.isPlaying ? "Pause" : "Play")
            
            // Fast-Forward 15s
            GlassIconButton(
                iconSystemName: "goforward.15",
                size: 30,
                iconSize: 12,
                helpText: "Fast-Forward 15 Seconds",
                action: { mediaService.fastForward(seconds: 15) }
            )
            
            // Next Track
            GlassIconButton(
                iconSystemName: "forward.fill",
                size: 28,
                iconSize: 12,
                helpText: "Next Track",
                action: { mediaService.nextTrack() }
            )
            
            Spacer()
            
            // Repeat Button (Off / All / One)
            GlassIconButton(
                iconSystemName: mediaService.repeatMode.iconName,
                size: 28,
                iconSize: 11,
                accentColor: mediaService.repeatMode != .off ? mediaService.activeSource.brandAccentColor : nil,
                helpText: mediaService.repeatMode == .off ? "Repeat: Off" : (mediaService.repeatMode == .one ? "Repeat: One Track" : "Repeat: All (Playlist)"),
                action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                        mediaService.cycleRepeatMode()
                    }
                }
            )
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }
    
    // MARK: - 5. Volume & Library Drawer Toggle Bar
    
    private var volumeAndDrawerBar: some View {
        HStack(spacing: 8) {
            // Volume Slider & Mute Toggle
            HStack(spacing: 6) {
                Button(action: {
                    if mediaService.volume > 0 {
                        mediaService.setVolume(0.0)
                    } else {
                        mediaService.setVolume(0.75)
                    }
                }) {
                    Image(systemName: volumeIcon)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Toggle Mute")
                
                Slider(
                    value: Binding(
                        get: { mediaService.volume },
                        set: { mediaService.setVolume($0) }
                    ),
                    in: 0...1
                )
                .accentColor(mediaService.activeSource.brandAccentColor)
                .frame(width: 70)
            }
            
            Spacer()
            
            // Browse Playlists Drawer Button
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isLibraryExpanded.toggle()
                    if isLibraryExpanded {
                        mediaService.refreshPlaylists()
                    }
                }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: isLibraryExpanded ? "chevron.up.circle.fill" : "music.note.list")
                        .font(.system(size: 11))
                        .foregroundColor(mediaService.activeSource.brandAccentColor)
                    
                    Text(isLibraryExpanded ? "Close Playlists" : "Playlists")
                        .font(AppTypography.micro)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.white.opacity(0.12)))
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 0.6))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }
    
    private var volumeIcon: String {
        if mediaService.volume == 0 {
            return "speaker.slash.fill"
        } else if mediaService.volume < 0.33 {
            return "speaker.wave.1.fill"
        } else if mediaService.volume < 0.66 {
            return "speaker.wave.2.fill"
        } else {
            return "speaker.wave.3.fill"
        }
    }
    
    // MARK: - 6. Expandable Library Playlists Drawer
    
    private var libraryDrawer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .background(Color.white.opacity(0.15))
            
            // Drawer Header
            HStack {
                Text("Your \(mediaService.activeSource.shortName) Library Playlists")
                    .font(AppTypography.captionBold)
                    .foregroundColor(.white.opacity(0.85))
                
                Spacer()
            }
            
            // Playlists List
            playlistsTabContent
        }
        .padding(8)
        .liquidPillStyle(cornerRadius: 12)
    }
    
    // MARK: - Drawer Subviews
    
    private var playlistsTabContent: some View {
        VStack(spacing: 6) {
            if mediaService.playlists.isEmpty {
                VStack(spacing: 6) {
                    Text("No \(mediaService.activeSource.shortName) playlists found.")
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("Play playlists in \(mediaService.activeSource.shortName) to automatically see them here.")
                        .font(AppTypography.micro)
                        .foregroundColor(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 12)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 6) {
                        ForEach(mediaService.playlists) { playlist in
                            PlaylistRow(
                                playlist: playlist,
                                onPlay: { mediaService.playPlaylist(playlist) }
                            )
                        }
                    }
                    .background(
                        ScrollEdgeFadeObserver(fadeLength: 16.0, fadeThreshold: 12.0)
                    )
                }
                .frame(maxHeight: 180)
            }
        }
    }
    
    private func formatSeconds(_ seconds: Double) -> String {
        guard !seconds.isNaN && !seconds.isInfinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Row Subviews

private struct PlaylistRow: View {
    let playlist: MediaPlaylist
    let onPlay: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 8) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(playlist.source.brandAccentColor.opacity(0.25))
                        .frame(width: 28, height: 28)
                    Image(systemName: playlist.source.iconName)
                        .font(.system(size: 11))
                        .foregroundColor(playlist.source.brandAccentColor)
                }
                
                // Name & Source
                VStack(alignment: .leading, spacing: 1) {
                    Text(playlist.name)
                        .font(AppTypography.captionBold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(playlist.description.isEmpty ? "\(playlist.source.shortName) Playlist" : playlist.description)
                        .font(AppTypography.micro)
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
                
                // Play Button Indicator
                Image(systemName: "play.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.white)
                    .padding(5)
                    .background(Circle().fill(playlist.source.brandAccentColor))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
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

private struct SongRow: View {
    let track: MediaTrackItem
    let onPlay: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 8) {
                // Mini Artwork or Icon
                ZStack {
                    if let artURL = track.artworkURL {
                        AsyncImage(url: artURL) { phase in
                            if let image = phase.image {
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(track.source.brandAccentColor.opacity(0.35))
                            }
                        }
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(track.source.brandAccentColor.opacity(0.35))
                    }
                    
                    if isHovered {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.45))
                        Image(systemName: "play.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                
                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title)
                        .font(AppTypography.captionBold)
                        .foregroundColor(isHovered ? track.source.brandAccentColor : .white)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Text(track.artist)
                            .font(AppTypography.micro)
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)
                        
                        if !track.album.isEmpty && track.album != track.title {
                            Text("•")
                                .font(AppTypography.micro)
                                .foregroundColor(.white.opacity(0.3))
                            Text(track.album)
                                .font(AppTypography.micro)
                                .foregroundColor(.white.opacity(0.45))
                                .lineLimit(1)
                        }
                    }
                }
                
                Spacer()
                
                if !track.durationFormatted.isEmpty {
                    Text(track.durationFormatted)
                        .font(AppTypography.micro.monospacedDigit())
                        .foregroundColor(.white.opacity(0.45))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .liquidPillStyle(cornerRadius: 8, isHovered: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.12)) {
                self.isHovered = hovering
            }
        }
    }
}

private struct AlbumCoverPlaceholder: View {
    let source: MediaSource
    
    var body: some View {
        ZStack {
            // Elegant subtle vinyl grooves / album disc placeholder with zero music notes
            Circle()
                .stroke(Color.white.opacity(0.20), lineWidth: 1.0)
                .frame(width: 36, height: 36)
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1.0)
                .frame(width: 24, height: 24)
            Circle()
                .fill(source.brandAccentColor.opacity(0.65))
                .frame(width: 14, height: 14)
            Circle()
                .fill(Color.black.opacity(0.85))
                .frame(width: 4, height: 4)
        }
        .frame(width: 48, height: 48)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

// MARK: - Daily Checklist Section View (Preserved)

public struct ChecklistSectionView: View {
    @ObservedObject public var checklistService: ChecklistService
    @State private var newTaskTitle = ""
    
    public init(checklistService: ChecklistService) {
        self.checklistService = checklistService
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header with Progress Badge
            HStack {
                SectionHeader(
                    title: "Daily Checklist",
                    iconSystemName: "checklist",
                    count: checklistService.items.count,
                    actionTitle: checklistService.completedCount > 0 ? "Clear Done" : nil,
                    onAction: { checklistService.clearCompleted() }
                )
                
                Spacer()
                
                // Liquid Progress Badge
                if !checklistService.items.isEmpty {
                    HStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .stroke(Color.white.opacity(0.15), lineWidth: 2.5)
                                .frame(width: 14, height: 14)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(checklistService.progressPercentage))
                                .stroke(GlassTheme.accentEmerald, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                                .frame(width: 14, height: 14)
                                .rotationEffect(.degrees(-90))
                        }
                        
                        Text("\(checklistService.completedCount)/\(checklistService.items.count)")
                            .font(AppTypography.micro)
                            .foregroundColor(checklistService.progressPercentage >= 1.0 ? GlassTheme.accentEmerald : .white.opacity(0.75))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .liquidPillStyle(cornerRadius: 10)
                }
            }
            
            // Task List (Full Row Click to Toggle)
            if checklistService.items.isEmpty {
                HStack {
                    Spacer()
                    Text("No tasks yet. Add one below to stay productive!")
                        .font(AppTypography.caption)
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.vertical, 6)
                    Spacer()
                }
            } else {
                VStack(spacing: 6) {
                    ForEach(checklistService.items) { item in
                        ChecklistItemRow(item: item) {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                                checklistService.toggleItem(item)
                            }
                        } onDelete: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                checklistService.removeItem(item)
                            }
                        }
                    }
                }
            }
            
            // New Task Input Box (Liquid Glass Pill)
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .foregroundColor(GlassTheme.accentCyan)
                    .font(.system(size: 14))
                
                TextField("Add task for today...", text: $newTaskTitle)
                    .textFieldStyle(.plain)
                    .font(AppTypography.body)
                    .foregroundColor(.white)
                    .onSubmit {
                        submitNewTask()
                    }
                
                if !newTaskTitle.isEmpty {
                    Button(action: submitNewTask) {
                        Text("Add")
                            .font(AppTypography.captionBold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(GlassTheme.accentBlue))
                            .shadow(color: GlassTheme.accentBlue.opacity(0.4), radius: 4, x: 0, y: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .liquidPillStyle(cornerRadius: 12)
        }
    }
    
    private func submitNewTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        checklistService.addItem(title: title)
        newTaskTitle = ""
    }
}

private struct ChecklistItemRow: View {
    let item: ChecklistItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 10) {
                // Checkbox Icon
                Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(item.isCompleted ? GlassTheme.accentEmerald : .white.opacity(0.45))
                    .scaleEffect(item.isCompleted ? 1.08 : 1.0)
                
                // Task Title
                Text(item.title)
                    .font(AppTypography.body)
                    .foregroundColor(item.isCompleted ? .white.opacity(0.40) : .white.opacity(0.95))
                    .strikethrough(item.isCompleted, color: GlassTheme.accentEmerald.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                Spacer()
                
                // Delete Action on Hover
                if isHovered {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(4)
                            .background(Circle().fill(Color.white.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                    .help("Delete task")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .liquidPillStyle(cornerRadius: 12, isHovered: isHovered)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(item.isCompleted ? AnyShapeStyle(GlassTheme.accentEmerald.opacity(0.6)) : (isHovered ? AnyShapeStyle(GlassTheme.liquidSpecularHoverBorder) : AnyShapeStyle(GlassTheme.subtleSpecularBorder)), lineWidth: 0.65)
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
}
