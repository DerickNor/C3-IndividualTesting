import Foundation
import SwiftUI

@Observable
class TimelineEditorViewModel {
    var project: VideoProject
    var timeline: Timeline
    
    // Playback state
    var isPlaying: Bool = false
    var isMuted: Bool = false
    var currentTime: TimeInterval = 0.0
    
    // UI state
    var zoomLevel: CGFloat = 1.0
    
    init(project: VideoProject) {
        self.project = project
        
        // Start with an empty timeline for a new project
        self.timeline = Timeline(clips: [])
    }
    
    func togglePlayback() {
        isPlaying.toggle()
        // In a real app, this would start a CADisplayLink or AVPlayer timer
    }
}
