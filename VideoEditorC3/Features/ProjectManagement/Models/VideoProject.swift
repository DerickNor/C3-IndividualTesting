import Foundation

/// Represents the aspect ratio / canvas size of the video project.
enum CanvasSize: String, CaseIterable, Hashable, Codable {
    case story = "9:16 (Story/TikTok)"
    case feed = "4:5 (Instagram Feed)"
    case square = "1:1 (Square)"
    case landscape = "16:9 (YouTube)"
    
    var aspectRatio: CGFloat {
        switch self {
        case .story: return 9.0 / 16.0
        case .feed: return 4.0 / 5.0
        case .square: return 1.0
        case .landscape: return 16.0 / 9.0
        }
    }
}

/// Represents a video editing project.
struct VideoProject: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    let creationDate: Date
    var lastModifiedDate: Date
    var thumbnailData: Data? // Optional thumbnail data, e.g., PNG/JPEG data
    var canvasSize: CanvasSize
    var timeline: Timeline
    
    init(id: UUID = UUID(), title: String, creationDate: Date = Date(), lastModifiedDate: Date = Date(), thumbnailData: Data? = nil, canvasSize: CanvasSize = .story, timeline: Timeline = Timeline()) {
        self.id = id
        self.title = title
        self.creationDate = creationDate
        self.lastModifiedDate = lastModifiedDate
        self.thumbnailData = thumbnailData
        self.canvasSize = canvasSize
        self.timeline = timeline
    }
}
