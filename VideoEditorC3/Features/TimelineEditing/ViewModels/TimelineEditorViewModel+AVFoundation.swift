import Foundation
import AVFoundation

extension TimelineEditorViewModel {
    
    // MARK: - Playback Controls
    
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
    
    func play() {
        if !isPlaying {
            togglePlayback()
        }
    }
    
    func pause() {
        if isPlaying {
            togglePlayback()
        }
    }
    
    func removeTimeObserver() {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
    }
    
    func handlePlaybackEnded() {
        isPlaying = false
        removeTimeObserver()
        // Seek back to beginning so next play starts fresh
        player.seek(to: .zero)
        currentTime = 0
    }
    
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
    
    // MARK: - Composition Builder
    
    @MainActor
    func rebuildComposition() async {
        let newComposition = AVMutableComposition()
        
        let trackTypes = Set(timeline.clips.map { $0.trackType }).sorted()
        
        for trackType in trackTypes {
            let clipsInTrack = timeline.clips.filter { $0.trackType == trackType }.sorted { $0.startTime < $1.startTime }
            
            let compVideoTrack = newComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
            let compAudioTrack = newComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            
            for clip in clipsInTrack {
                guard let url = clip.url else { continue }
                let asset = AVURLAsset(url: url)
                
                do {
                    let timeRange = CMTimeRange(start: CMTime(seconds: clip.sourceStartTime, preferredTimescale: 600), duration: CMTime(seconds: clip.duration, preferredTimescale: 600))
                    let startTime = CMTime(seconds: clip.startTime, preferredTimescale: 600)
                    
                    if let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first {
                        try? compVideoTrack?.insertTimeRange(timeRange, of: assetVideoTrack, at: startTime)
                        
                        // Apply the source video's orientation transform so vertical videos
                        // are not displayed sideways in the composition
                        let transform = try await assetVideoTrack.load(.preferredTransform)
                        compVideoTrack?.preferredTransform = transform
                    }
                    
                    if let assetAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
                        try? compAudioTrack?.insertTimeRange(timeRange, of: assetAudioTrack, at: startTime)
                    }
                } catch {
                    print("Error loading tracks for composition: \(error)")
                }
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
}
