import SwiftUI
import Combine

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

@available(iOS 18.0, *)
struct TimelineEditorView: View {
    @State private var viewModel: TimelineEditorViewModel
    // Tab state and tooltip control
    @State private var selectedTab: EditorTool = .edit
    @State private var activeTooltip: EditorTool? = nil
    @State private var showDeleteAlert = false
    
    // Hardcoded scale for the dummy timeline: 20 points per second
    let pointsPerSecond: CGFloat = 75
    
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
                                if tool == .delete {
                                    if viewModel.selectedClipID != nil {
                                        showDeleteAlert = true
                                    }
                                    return
                                }
                                
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
                                .foregroundColor(tool == .delete ? (viewModel.selectedClipID != nil ? .red : .gray.opacity(0.5)) : (selectedTab == tool ? .white : .gray))
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
        .alert("Hapus Scene?", isPresented: $showDeleteAlert) {
            Button("Batal", role: .cancel) { }
            Button("Hapus", role: .destructive) {
                if let id = viewModel.selectedClipID {
                    viewModel.deleteClip(id: id)
                    viewModel.selectedClipID = nil
                }
            }
        } message: {
            Text("Apakah Anda yakin ingin menghapus scene ini?")
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
    
    // Drag state for reordering
    @State private var dragReorderTranslation: CGFloat = 0
    @State private var initialStartTime: TimeInterval = 0
    
    // Drag state for trimming
    @State private var dragOffsetLeft: CGFloat = 0
    @State private var dragOffsetRight: CGFloat = 0
    
    // Auto-scroll trim states
    @State private var currentDragTranslation: CGFloat = 0
    @State private var accumulatedAutoScroll: CGFloat = 0
    @State private var isAutoScrollingLeft = false
    @State private var isAutoScrollingRight = false
    @State private var isDraggingLeft = false
    @State private var isDraggingRight = false
    @State private var isDraggingReorder = false
    
    let autoScrollTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    private func updateReorder() {
        let totalTranslation = currentDragTranslation + accumulatedAutoScroll
        dragReorderTranslation = totalTranslation
        
        viewModel.handleReorderDrag(
            clipID: clip.id,
            initialStartTime: initialStartTime,
            translation: totalTranslation,
            pointsPerSecond: pointsPerSecond
        )
        
        if isAutoScrollingLeft || isAutoScrollingRight {
            let newVirtualX = (initialStartTime * pointsPerSecond) + totalTranslation
            viewModel.currentTime = max(0, newVirtualX / pointsPerSecond)
            viewModel.syncScroll()
        }
    }
    
    private func updateTrimLeft() {
        let delta = currentDragTranslation + accumulatedAutoScroll
        let maxDelta = clip.duration * pointsPerSecond - 10
        let minDelta = -(clip.sourceStartTime * pointsPerSecond)
        dragOffsetLeft = min(max(minDelta, delta), maxDelta)
        let newStartTime = clip.startTime + (dragOffsetLeft / pointsPerSecond)
        viewModel.currentTime = newStartTime
        viewModel.syncScroll()
    }
    
    private func updateTrimRight() {
        let delta = currentDragTranslation + accumulatedAutoScroll
        let minDelta = -(clip.duration * pointsPerSecond) + 10
        let maxDelta = (clip.assetDuration - clip.sourceStartTime - clip.duration) * pointsPerSecond
        dragOffsetRight = min(max(minDelta, delta), maxDelta)
        let newEndTime = clip.startTime + clip.duration + (dragOffsetRight / pointsPerSecond)
        viewModel.currentTime = newEndTime
        viewModel.syncScroll()
    }
    
    
    var isSelected: Bool { viewModel.selectedClipID == clip.id }
    
    var body: some View {
        let currentWidth = max(0, clip.duration * pointsPerSecond) + dragOffsetRight - dragOffsetLeft
        let isDragged = viewModel.draggedClipID == clip.id
        let baseOffset = isDragged ? (initialStartTime * pointsPerSecond + dragReorderTranslation) : (clip.startTime * pointsPerSecond)
        
        return ZStack(alignment: .leading) {
            
            // ── Tap target layer (background + filmstrip + border) ──────────
            // This is the only area that responds to tap for select/deselect.
            // It is BELOW the handles so drag gestures on handles are never intercepted.
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.black.opacity(isSelected ? 0.0 : 0.5))
                
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
                    .opacity(isSelected ? 1.0 : 0.6)
                }
                
                Rectangle()
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.4),
                            lineWidth: isSelected ? 2 : 1)
            }
            .padding(.leading, clip.startTime == 0 ? 0 : 4)
            .padding(.trailing, 4)
            .contentShape(Rectangle())
            .onTapGesture {
                // Toggle selection — deselect if already selected
                viewModel.selectedClipID = (viewModel.selectedClipID == clip.id) ? nil : clip.id
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .global)
                    .onChanged { value in
                        if viewModel.draggedClipID != clip.id {
                            viewModel.draggedClipID = clip.id
                            initialStartTime = clip.startTime
                        }
                        
                        isDraggingReorder = true
                        currentDragTranslation = value.translation.width
                        
                        let globalX = value.location.x
                        let screenWidth = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 400
                        isAutoScrollingLeft = globalX < 80
                        isAutoScrollingRight = globalX > screenWidth - 80
                        
                        updateReorder()
                    }
                    .onEnded { _ in
                        isDraggingReorder = false
                        isAutoScrollingLeft = false
                        isAutoScrollingRight = false
                        
                        viewModel.snapshotForUndo()
                        viewModel.draggedClipID = nil
                        dragReorderTranslation = 0
                        currentDragTranslation = 0
                        accumulatedAutoScroll = 0
                        Task { await viewModel.rebuildComposition(); viewModel.save() }
                    }
            )
            
            // ── Trim Handles (high-priority drag, only when selected) ───────
            if isSelected {
                HStack(spacing: 0) {
                    // Left Handle
                    ZStack {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 14)
                        Rectangle()
                            .fill(Color.gray.opacity(0.8))
                            .frame(width: 2, height: 16)
                    }
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                                .onChanged { value in
                                    isDraggingLeft = true
                                    currentDragTranslation = value.translation.width
                                    let globalX = value.location.x
                                    let screenWidth = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 400
                                    isAutoScrollingLeft = globalX < 80
                                    isAutoScrollingRight = globalX > screenWidth - 80
                                    updateTrimLeft()
                                }
                                .onEnded { _ in
                                    isDraggingLeft = false
                                    isAutoScrollingLeft = false
                                    isAutoScrollingRight = false
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
                                    currentDragTranslation = 0
                                    accumulatedAutoScroll = 0
                                }
                        )
                    
                    Spacer()
                    
                    // Right Handle
                    ZStack {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 14)
                        Rectangle()
                            .fill(Color.gray.opacity(0.8))
                            .frame(width: 2, height: 16)
                    }
                        .highPriorityGesture(
                            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                                .onChanged { value in
                                    isDraggingRight = true
                                    currentDragTranslation = value.translation.width
                                    let globalX = value.location.x
                                    let screenWidth = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 400
                                    isAutoScrollingLeft = globalX < 80
                                    isAutoScrollingRight = globalX > screenWidth - 80
                                    updateTrimRight()
                                }
                                .onEnded { _ in
                                    isDraggingRight = false
                                    isAutoScrollingLeft = false
                                    isAutoScrollingRight = false
                                    let timeOffset = dragOffsetRight / pointsPerSecond
                                    viewModel.updateClipTrim(
                                        id: clip.id,
                                        startTime: clip.startTime,
                                        duration: clip.duration + timeOffset,
                                        sourceStartTime: clip.sourceStartTime,
                                        resetToStart: false
                                    )
                                    dragOffsetRight = 0
                                    currentDragTranslation = 0
                                    accumulatedAutoScroll = 0
                                }
                        )
                }
            }
        }
        .frame(width: max(0, currentWidth), height: max(trackHeight - 4, 10))
        .offset(x: baseOffset + dragOffsetLeft)
        .scaleEffect(isDragged ? 1.05 : 1.0)
        .zIndex(isDragged ? 100 : 0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragged)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: clip.startTime)
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
        .onReceive(autoScrollTimer) { _ in
            guard isDraggingLeft || isDraggingRight || isDraggingReorder else { return }
            var direction: CGFloat = 0
            if isAutoScrollingLeft { direction = -1 }
            else if isAutoScrollingRight { direction = 1 }
            else { return }
            
            accumulatedAutoScroll += direction * 20
            
            if isDraggingLeft {
                updateTrimLeft()
            } else if isDraggingRight {
                updateTrimRight()
            } else if isDraggingReorder {
                updateReorder()
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
