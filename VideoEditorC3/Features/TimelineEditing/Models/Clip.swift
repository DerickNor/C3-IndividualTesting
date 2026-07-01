import Foundation
import SwiftUI

/// Represents the type of layer/track the clip belongs to.
enum TrackType: String, CaseIterable, Codable {
    case video = "Video"
    case audio = "Audio"
    case text = "Text"
}

/// Helper extension to serialize Color easily
extension Color {
    var hexString: String {
        if self == .blue { return "blue" }
        if self == .red { return "red" }
        if self == .green { return "green" }
        return "blue"
    }
    
    static func fromHex(_ hex: String) -> Color {
        switch hex {
        case "blue": return .blue
        case "red": return .red
        case "green": return .green
        default: return .blue
        }
    }
}

/// Represents a single clip on the timeline (video, audio, or text).
struct Clip: Identifiable, Hashable, Codable {
    let id: UUID
    var name: String
    var startTime: TimeInterval
    var duration: TimeInterval
    var color: Color
    var trackType: TrackType
    var relativePath: String?
    var sourceStartTime: TimeInterval
    var assetDuration: TimeInterval
    
    var url: URL? {
        guard let relativePath = relativePath else { return nil }
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL.appendingPathComponent(relativePath)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, startTime, duration, colorHex, trackType, relativePath, sourceStartTime, assetDuration
    }
    
    init(id: UUID = UUID(), name: String, startTime: TimeInterval, duration: TimeInterval, color: Color = .blue, trackType: TrackType = .video, url: URL? = nil, sourceStartTime: TimeInterval = 0.0, assetDuration: TimeInterval = 0.0) {
        self.id = id
        self.name = name
        self.startTime = startTime
        self.duration = duration
        self.color = color
        self.trackType = trackType
        self.relativePath = url?.lastPathComponent
        self.sourceStartTime = sourceStartTime
        self.assetDuration = assetDuration
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        startTime = try container.decode(TimeInterval.self, forKey: .startTime)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        trackType = try container.decode(TrackType.self, forKey: .trackType)
        relativePath = try container.decodeIfPresent(String.self, forKey: .relativePath)
        sourceStartTime = try container.decode(TimeInterval.self, forKey: .sourceStartTime)
        assetDuration = try container.decode(TimeInterval.self, forKey: .assetDuration)
        
        let colorHex = try container.decode(String.self, forKey: .colorHex)
        color = Color.fromHex(colorHex)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(duration, forKey: .duration)
        try container.encode(trackType, forKey: .trackType)
        try container.encode(relativePath, forKey: .relativePath)
        try container.encode(sourceStartTime, forKey: .sourceStartTime)
        try container.encode(assetDuration, forKey: .assetDuration)
        try container.encode(color.hexString, forKey: .colorHex)
    }
}
