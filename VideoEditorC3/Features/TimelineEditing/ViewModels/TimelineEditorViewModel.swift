import Foundation
import SwiftUI
import AVFoundation
import PhotosUI

@Observable
class TimelineEditorViewModel {
    var project: VideoProject
    var timeline: Timeline
    
    // MARK: - Playback State
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
    
    // MARK: - Playback Engine
    @ObservationIgnored var player: AVPlayer = AVPlayer()
    @ObservationIgnored var composition: AVMutableComposition?
    @ObservationIgnored var timeObserver: Any?
    @ObservationIgnored var endObserver: Any?
    @ObservationIgnored var isSeeking = false
    @ObservationIgnored var pendingSeekTime: CMTime? = nil
    
    // MARK: - UI State
    var zoomLevel: CGFloat = 1.0
    var isShowingVideoPicker: Bool = false
    var isShowingAudioImporter: Bool = false
    
    // MARK: - Selection & Drag State
    var selectedClipID: UUID? = nil
    var draggedClipID: UUID? = nil
    
    // MARK: - History State
    @ObservationIgnored var undoStack: [Timeline] = []
    @ObservationIgnored var redoStack: [Timeline] = []
    
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    
    // MARK: - Scroll Sync Token
    // Token to force the scroll view to sync position without feedback loop
    var scrollSyncToken: UUID = UUID()
    
    // MARK: - Callbacks
    @ObservationIgnored var onSave: ((VideoProject) -> Void)?
    
    // MARK: - Initialization
    init(project: VideoProject, onSave: ((VideoProject) -> Void)? = nil) {
        self.project = project
        self.timeline = project.timeline
        self.onSave = onSave
        
        // Build the composition immediately so that loaded scenes can be previewed
        Task { @MainActor in
            await self.rebuildComposition()
        }
    }
    
    // MARK: - Save
    func save() {
        project.timeline = timeline
        onSave?(project)
    }
    
    // MARK: - Helper Methods
    var availableTracks: [Int] {
        var tracks = Set(timeline.clips.map { $0.trackType })
        tracks.insert(0)
        return tracks.sorted()
    }
    
    /// Call this to programmatically scroll timeline to currentTime
    func syncScroll() {
        scrollSyncToken = UUID()
    }
}
