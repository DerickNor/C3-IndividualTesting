import Foundation

/// Represents the overall timeline state for a video project.
struct Timeline {
    var clips: [Clip]
    var totalDuration: TimeInterval {
        clips.map { $0.startTime + $0.duration }.max() ?? 0
    }
    
    init(clips: [Clip] = []) {
        self.clips = clips
    }
}
