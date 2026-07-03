import Foundation

enum EditorTool: String, CaseIterable, Identifiable {
    case ai, edit, audio, text, overlay, captions, delete
    
    var id: String { self.rawValue }
    
    var title: String {
        switch self {
        case .ai: return "AI"
        case .edit: return "Edit"
        case .audio: return "Audio"
        case .text: return "Text"
        case .overlay: return "Overlay"
        case .captions: return "Captions"
        case .delete: return "Delete"
        }
    }
    
    var iconName: String {
        switch self {
        case .ai: return "sparkles"
        case .edit: return "scissors"
        case .audio: return "waveform"
        case .text: return "textformat"
        case .overlay: return "square.on.square"
        case .captions: return "captions.bubble"
        case .delete: return "trash"
        }
    }
}
