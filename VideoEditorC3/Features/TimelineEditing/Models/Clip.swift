import Foundation
import SwiftUI

/// Represents the type of layer/track the clip belongs to.
enum TrackType: String, CaseIterable {
    case video = "Video"
    case audio = "Audio"
    case text = "Text"
}

/// Represents a single clip on the timeline (video, audio, or text).
struct Clip: Identifiable, Hashable {
    let id: UUID
    var name: String
    var startTime: TimeInterval
    var duration: TimeInterval
    var color: Color
    var trackType: TrackType
    
    init(id: UUID = UUID(), name: String, startTime: TimeInterval, duration: TimeInterval, color: Color = .blue, trackType: TrackType = .video) {
        self.id = id
        self.name = name
        self.startTime = startTime
        self.duration = duration
        self.color = color
        self.trackType = trackType
    }
}
