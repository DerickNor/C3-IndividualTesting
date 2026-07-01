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
    let pointsPerSecond: CGFloat = 100
    
    init(project: VideoProject, onSave: ((VideoProject) -> Void)? = nil) {
        // Initialize the view model with the selected project and onSave callback
        _viewModel = State(initialValue: TimelineEditorViewModel(project: project, onSave: onSave))
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
                                    TooltipMenuItem(id: "sequence", icon: "film", title: "Auto-Sequence")
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
import AVFoundation

struct TimelineClipView: View {
    let clip: Clip
    let pointsPerSecond: CGFloat
    let trackHeight: CGFloat
    let viewModel: TimelineEditorViewModel
    
    @State private var thumbnails: [UIImage] = []
    
    // Drag state for trimming
    @State private var dragOffsetLeft: CGFloat = 0
    @State private var dragOffsetRight: CGFloat = 0
    
    
    var isSelected: Bool { viewModel.selectedClipID == clip.id }
    
    var body: some View {
        let currentWidth = max(0, clip.duration * pointsPerSecond) + dragOffsetRight - dragOffsetLeft
        
        ZStack(alignment: .leading) {
            
            // ── Tap target layer (background + filmstrip + border) ──────────
            // This is the only area that responds to tap for select/deselect.
            // It is BELOW the handles so drag gestures on handles are never intercepted.
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.5))
                
                if !thumbnails.isEmpty {
                    GeometryReader { geo in
                        HStack(spacing: 0) {
                            ForEach(0..<thumbnails.count, id: \.self) { i in
                                Image(uiImage: thumbnails[i])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: geo.size.height, height: geo.size.height)
                                    .clipped()
                            }
                        }
                    }
                    .frame(height: max(trackHeight - 4, 10))
                    .clipped()
                    .opacity(0.6)
                }
                
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.25),
                            lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Toggle selection — deselect if already selected
                viewModel.selectedClipID = (viewModel.selectedClipID == clip.id) ? nil : clip.id
            }
            
            // ── Trim Handles (high-priority drag, only when selected) ───────
            if isSelected {
                HStack(spacing: 0) {
                    // Left Handle
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 14)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, bottomLeadingRadius: 4))
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    let delta = value.translation.width
                                    let maxDelta = clip.duration * pointsPerSecond - 10
                                    let minDelta = -(clip.sourceStartTime * pointsPerSecond)
                                    dragOffsetLeft = min(max(minDelta, delta), maxDelta)
                                    let newStartTime = clip.startTime + (dragOffsetLeft / pointsPerSecond)
                                    viewModel.currentTime = newStartTime
                                }
                                .onEnded { _ in
                                    let timeOffset = dragOffsetLeft / pointsPerSecond
                                    // startTime stays fixed — clip always snaps back to its timeline position
                                    // Only sourceStartTime advances (skip that many seconds in source video)
                                    viewModel.updateClipTrim(
                                        id: clip.id,
                                        startTime: clip.startTime,
                                        duration: clip.duration - timeOffset,
                                        sourceStartTime: clip.sourceStartTime + timeOffset,
                                        resetToStart: clip.startTime == 0
                                    )
                                    dragOffsetLeft = 0
                                }
                        )
                    
                    Spacer()
                    
                    // Right Handle
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 14)
                        .clipShape(UnevenRoundedRectangle(bottomTrailingRadius: 4, topTrailingRadius: 4))
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 1)
                                .onChanged { value in
                                    let delta = value.translation.width
                                    let minDelta = -(clip.duration * pointsPerSecond) + 10
                                    let maxDelta = (clip.assetDuration - clip.sourceStartTime - clip.duration) * pointsPerSecond
                                    dragOffsetRight = min(max(minDelta, delta), maxDelta)
                                    let newEndTime = clip.startTime + clip.duration + (dragOffsetRight / pointsPerSecond)
                                    viewModel.currentTime = newEndTime
                                }
                                .onEnded { _ in
                                    let timeOffset = dragOffsetRight / pointsPerSecond
                                    viewModel.updateClipTrim(
                                        id: clip.id,
                                        startTime: clip.startTime,
                                        duration: clip.duration + timeOffset,
                                        sourceStartTime: clip.sourceStartTime,
                                        resetToStart: false
                                    )
                                    dragOffsetRight = 0
                                }
                        )
                }
            }
        }
        .frame(width: max(0, currentWidth), height: max(trackHeight - 4, 10))
        .offset(x: (clip.startTime * pointsPerSecond) + dragOffsetLeft)
        .animation(nil, value: dragOffsetLeft)
        .animation(nil, value: dragOffsetRight)
        .task {
            if let url = clip.url, thumbnails.isEmpty {
                generateFilmstrip(from: url, duration: clip.duration)
            }
        }
        .onChange(of: clip.duration) { _, newDuration in
            // Regenerate filmstrip if duration significantly changes
            if let url = clip.url {
                generateFilmstrip(from: url, duration: newDuration)
            }
        }
    }
    
    private func generateFilmstrip(from url: URL, duration: TimeInterval) {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 150, height: 150)
        
        // Calculate how many thumbnails we need (e.g. 1 per second, but bound to track height vs width)
        let totalWidth = duration * pointsPerSecond
        let thumbWidth = max(trackHeight - 4, 10)
        let count = max(1, Int(totalWidth / thumbWidth))
        
        var times: [CMTime] = []
        for i in 0..<count {
            let t = (duration / Double(count)) * Double(i) + clip.sourceStartTime
            times.append(CMTime(seconds: t, preferredTimescale: 600))
        }
        
        Task {
            var newThumbnails: [UIImage] = []
            
            do {
                for try await result in generator.images(for: times) {
                    let cgImage = try result.image
                    let uiImage = UIImage(cgImage: cgImage)
                    newThumbnails.append(uiImage)
                }
                
                await MainActor.run {
                    self.thumbnails = newThumbnails
                }
            } catch {
                print("Failed to generate filmstrip: \(error)")
            }
        }
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
