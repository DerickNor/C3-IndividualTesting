import SwiftUI

enum EditorTool: String, CaseIterable, Identifiable {
    case ai, edit, audio, text, overlay, effects, filters
    
    var id: String { self.rawValue }
    
    var title: String {
        switch self {
        case .ai: return "AI"
        case .edit: return "Edit"
        case .audio: return "Audio"
        case .text: return "Text"
        case .overlay: return "Overlay"
        case .effects: return "Effects"
        case .filters: return "Filters"
        }
    }
    
    var iconName: String {
        switch self {
        case .ai: return "sparkles"
        case .edit: return "scissors"
        case .audio: return "waveform"
        case .text: return "textformat"
        case .overlay: return "square.on.square"
        case .effects: return "wand.and.stars"
        case .filters: return "camera.filters"
        }
    }
}

@available(iOS 18.0, *)
struct TimelineEditorView: View {
    @State private var viewModel: TimelineEditorViewModel
    // Tab state and tooltip control
    @State private var selectedTab: EditorTool = .edit
    @State private var activeTooltip: EditorTool? = nil
    
    // Hardcoded scale for the dummy timeline: 20 points per second
    let pointsPerSecond: CGFloat = 20
    
    init(project: VideoProject) {
        // Initialize the view model with the selected project
        _viewModel = State(initialValue: TimelineEditorViewModel(project: project))
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Single workspace view that never gets destroyed
                TimelineWorkspaceView(viewModel: viewModel, pointsPerSecond: pointsPerSecond)
                
                // Custom Bottom Toolbar
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(EditorTool.allCases) { tool in
                            Button(action: {
                                // Tap logic identical to tabSelectionBinding
                                if selectedTab == tool {
                                    if tool == .ai || tool == .edit {
                                        withAnimation(.spring) {
                                            activeTooltip = (activeTooltip == tool) ? nil : tool
                                        }
                                    }
                                } else {
                                    selectedTab = tool
                                    if tool == .ai || tool == .edit {
                                        withAnimation(.spring) {
                                            activeTooltip = tool
                                        }
                                    } else {
                                        withAnimation { activeTooltip = nil }
                                    }
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: tool.iconName)
                                        .font(.system(size: 20))
                                    Text(tool.title)
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(selectedTab == tool ? .white : .gray)
                                .frame(width: 56) // Fixed width for consistent spacing
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .background(Color(.systemGray6))
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    if activeTooltip != nil {
                        withAnimation { activeTooltip = nil }
                    }
                }
            )
            
            if let tool = activeTooltip {
                VStack {
                    Spacer()
                    HStack {
                        if tool == .ai {
                            EditorTooltipMenu(
                                items: [
                                    TooltipMenuItem(id: "cut", icon: "scissors", title: "Auto-Cut"),
                                    TooltipMenuItem(id: "caption", icon: "captions.bubble", title: "Auto-Caption"),
                                    TooltipMenuItem(id: "sequence", icon: "wand.and.stars", title: "Auto-Sequence")
                                ],
                                arrowOffset: 24
                            ) { _ in
                                withAnimation { activeTooltip = nil }
                            }
                            .padding(.leading, 16)
                            .padding(.bottom, 60)
                            
                        } else if tool == .edit {
                            EditorTooltipMenu(
                                items: [
                                    TooltipMenuItem(id: "split", icon: "scissors.badge.ellipsis", title: "Split"),
                                    TooltipMenuItem(id: "volume", icon: "speaker.wave.2.fill", title: "Volume")
                                ],
                                arrowOffset: 24 // Offset within the tooltip box
                            ) { _ in
                                withAnimation { activeTooltip = nil }
                            }
                            // Shift the tooltip to roughly align above the 2nd tab
                            // 16 padding + approx 56pt per tab width
                            .padding(.leading, 16 + 56)
                            .padding(.bottom, 60)
                        }
                        Spacer()
                    }
                }
                .transition(.scale(scale: 0.8, anchor: tool == .ai ? .bottomLeading : .bottom).combined(with: .opacity))
                .zIndex(1)
            }
        }
        .navigationTitle(viewModel.project.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// Subview for a single clip on the timeline
struct TimelineClipView: View {
    let clip: Clip
    let pointsPerSecond: CGFloat
    let trackHeight: CGFloat
    
    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(clip.color.opacity(0.8))
            
            RoundedRectangle(cornerRadius: 6)
                .stroke(clip.color, lineWidth: 1)
            
            Text(clip.name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .lineLimit(1)
        }
        .frame(width: clip.duration * pointsPerSecond, height: max(trackHeight - 4, 10)) // Leave 4pt margin total (2pt top, 2pt bottom)
        .offset(x: clip.startTime * pointsPerSecond) // Horizontal offset based on start time
    }
}

#Preview {
    if #available(iOS 18.0, *) {
        NavigationStack {
            TimelineEditorView(project: VideoProject(title: "My Awesome Video"))
        }
    } else {
        Text("Requires iOS 18")
    }
}
