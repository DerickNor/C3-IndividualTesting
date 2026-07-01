import Foundation
import SwiftUI
import PhotosUI
import AVFoundation

@Observable
class TimelineEditorViewModel {
    var project: VideoProject
    var timeline: Timeline
    
    // Playback state
    var isPlaying: Bool = false
    var isMuted: Bool = false {
        didSet {
            player.isMuted = isMuted
        }
    }
    var currentTime: TimeInterval = 0.0 {
        didSet {
            if !isPlaying {
                scrub(to: currentTime)
            }
        }
    }
    
    // Playback Engine
    @ObservationIgnored var player: AVPlayer = AVPlayer()
    @ObservationIgnored private var composition: AVMutableComposition?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var endObserver: Any?
    
    // UI state
    var zoomLevel: CGFloat = 1.0
    
    // Picker State
    var isShowingVideoPicker: Bool = false
    
    // Selection state for trim handles
    var selectedClipID: UUID? = nil
    
    // Token to force the scroll view to sync position without feedback loop
    var scrollSyncToken: UUID = UUID()
    
    /// Call this to programmatically scroll timeline to currentTime
    func syncScroll() {
        scrollSyncToken = UUID()
    }
    
    // Callback to save project changes
    var onSave: ((VideoProject) -> Void)?
    
    init(project: VideoProject, onSave: ((VideoProject) -> Void)? = nil) {
        self.project = project
        self.timeline = project.timeline
        self.onSave = onSave
        
        // Build the composition immediately so that loaded scenes can be previewed
        Task { @MainActor in
            await self.rebuildComposition()
        }
    }
    
    func save() {
        project.timeline = timeline
        onSave?(project)
    }
    
    func togglePlayback() {
        isPlaying.toggle()
        if isPlaying {
            // If at end, restart from beginning
            if let duration = player.currentItem?.duration,
               player.currentTime() >= duration {
                player.seek(to: .zero)
            }
            player.play()
            // Observe player time at ~30fps to drive timeline scroll
            let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: CMTimeScale(NSEC_PER_SEC))
            timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
                guard let self = self, self.isPlaying else { return }
                self.currentTime = time.seconds
            }
        } else {
            player.pause()
            removeTimeObserver()
        }
    }
    
    private func removeTimeObserver() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    private func handlePlaybackEnded() {
        isPlaying = false
        removeTimeObserver()
        // Seek back to beginning so next play starts fresh
        player.seek(to: .zero)
        currentTime = 0
    }
    
    private var isSeeking = false
    private var pendingSeekTime: CMTime? = nil
    
    func scrub(to time: TimeInterval, exact: Bool = false) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        
        if exact {
            pendingSeekTime = nil
            player.seek(to: cmTime, toleranceBefore: .zero, toleranceAfter: .zero)
        } else {
            if isSeeking {
                // Save the latest requested time to be processed after the current seek finishes
                pendingSeekTime = cmTime
                return
            }
            
            isSeeking = true
            // Use default tolerance (loose) for smooth jumping between keyframes while dragging, but throttle it via isSeeking
            player.seek(to: cmTime) { [weak self] _ in
                guard let self = self else { return }
                self.isSeeking = false
                
                // If there was another seek request while we were busy, execute it now
                if let pending = self.pendingSeekTime {
                    self.pendingSeekTime = nil
                    self.scrub(to: pending.seconds, exact: false)
                }
            }
        }
    }
    
    @MainActor
    private func rebuildComposition() async {
        let newComposition = AVMutableComposition()
        let videoTrack = newComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioTrack = newComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let videoClips = timeline.clips.filter { $0.trackType == .video }.sorted { $0.startTime < $1.startTime }
        
        for clip in videoClips {
            guard let url = clip.url else { continue }
            let asset = AVURLAsset(url: url)
            
            do {
                if let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first {
                    let timeRange = CMTimeRange(start: CMTime(seconds: clip.sourceStartTime, preferredTimescale: 600), duration: CMTime(seconds: clip.duration, preferredTimescale: 600))
                    let startTime = CMTime(seconds: clip.startTime, preferredTimescale: 600)
                    try? videoTrack?.insertTimeRange(timeRange, of: assetVideoTrack, at: startTime)
                    
                    // Apply the source video's orientation transform so vertical videos
                    // are not displayed sideways in the composition
                    let transform = try await assetVideoTrack.load(.preferredTransform)
                    videoTrack?.preferredTransform = transform
                }
                
                if let assetAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                    let timeRange = CMTimeRange(start: CMTime(seconds: clip.sourceStartTime, preferredTimescale: 600), duration: CMTime(seconds: clip.duration, preferredTimescale: 600))
                    let startTime = CMTime(seconds: clip.startTime, preferredTimescale: 600)
                    try? audioTrack?.insertTimeRange(timeRange, of: assetAudioTrack, at: startTime)
                }
            } catch {
                print("Error loading tracks for composition: \(error)")
            }
        }
        
        self.composition = newComposition
        let playerItem = AVPlayerItem(asset: newComposition)
        player.replaceCurrentItem(with: playerItem)
        
        // Remove old end observer and register a new one for the new item
        if let old = endObserver {
            NotificationCenter.default.removeObserver(old)
        }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.handlePlaybackEnded()
        }
    }
    
    @MainActor
    func addVideoClip(from item: PhotosPickerItem?) {
        guard let item = item else { return }
        addVideoClips(from: [item])
    }
    
    @MainActor
    func addVideoClips(from items: [PhotosPickerItem]) {
        guard !items.isEmpty else { return }
        
        Task {
            var newClips: [Clip] = []
            for item in items {
                do {
                    if let movie = try await item.loadTransferable(type: Movie.self) {
                        // Copy the video to the permanent documents directory to prevent URL expiration
                        let fileManager = FileManager.default
                        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let permanentURL = documentsURL.appendingPathComponent("\(UUID().uuidString).mov")
                        
                        try fileManager.copyItem(at: movie.url, to: permanentURL)
                        
                        let asset = AVURLAsset(url: permanentURL)
                        let duration = try await asset.load(.duration)
                        let seconds = duration.seconds
                        
                        let existingMax = timeline.clips.filter { $0.trackType == .video }.map { $0.startTime + $0.duration }.max() ?? 0
                        let newMax = newClips.map { $0.startTime + $0.duration }.max() ?? 0
                        let startTime = max(existingMax, newMax)
                        
                        let newClip = Clip(
                            id: UUID(),
                            name: "Video \(timeline.clips.count + newClips.count + 1)",
                            startTime: startTime,
                            duration: seconds,
                            color: .blue,
                            trackType: .video,
                            url: permanentURL,
                            assetDuration: seconds
                        )
                        newClips.append(newClip)
                    }
                } catch {
                    print("Failed to load video: \(error.localizedDescription)")
                }
            }
            
            if !newClips.isEmpty {
                self.timeline.clips.append(contentsOf: newClips)
                await self.rebuildComposition()
                self.save()
            }
        }
    }
    
    private func rippleClips(for trackType: TrackType) {
        // Sort clips of this track by their current startTime to preserve order
        let trackClips = timeline.clips.filter { $0.trackType == trackType }.sorted { $0.startTime < $1.startTime }
        
        var currentOffset: TimeInterval = 0.0
        for clip in trackClips {
            if let idx = timeline.clips.firstIndex(where: { $0.id == clip.id }) {
                timeline.clips[idx].startTime = currentOffset
                currentOffset += timeline.clips[idx].duration
            }
        }
    }
    
    @MainActor
    func updateClipTrim(id: UUID, startTime: TimeInterval, duration: TimeInterval, sourceStartTime: TimeInterval, resetToStart: Bool = true) {
        if let index = timeline.clips.firstIndex(where: { $0.id == id }) {
            let trackType = timeline.clips[index].trackType
            timeline.clips[index].startTime = max(0, startTime)
            timeline.clips[index].duration = max(0.1, duration)
            timeline.clips[index].sourceStartTime = max(0, sourceStartTime)
            
            // Ripple subsequent clips so they remain back-to-back without gaps
            rippleClips(for: trackType)
            
            // Rebuild composition and conditionally reset playhead to 00:00
            Task {
                await self.rebuildComposition()
                self.save()
                if resetToStart {
                    // After composition is ready, scroll timeline back to start
                    self.currentTime = 0
                    self.scrub(to: 0, exact: true)
                    self.syncScroll()
                } else {
                    // Keep current playhead position, just ensure player is synced to it exactly
                    self.scrub(to: self.currentTime, exact: true)
                }
            }
        }
    }
}
