import SwiftUI
import AVFoundation
import Combine

struct TimelineClipView: View {
    let clip: Clip
    let index: Int
    let pointsPerSecond: CGFloat
    let trackHeight: CGFloat
    let viewModel: TimelineEditorViewModel
    
    @State private var thumbnails: [UIImage] = []
    
    // Drag state for reordering
    @State private var dragReorderTranslation: CGFloat = 0
    @State private var initialStartTime: TimeInterval = 0
    @State private var initialIndex: Int = 0
    @State private var initialTrackIndex: Int = 0
    
    // Drag state for trimming
    @State private var dragOffsetLeft: CGFloat = 0
    @State private var dragOffsetRight: CGFloat = 0
    
    // Auto-scroll trim states
    @State private var currentDragTranslation: CGFloat = 0
    @State private var currentDragTranslationHeight: CGFloat = 0
    @State private var accumulatedAutoScroll: CGFloat = 0
    @State private var isAutoScrollingLeft = false
    @State private var isAutoScrollingRight = false
    @State private var isDraggingLeft = false
    @State private var isDraggingRight = false
    @State private var isDraggingReorder = false
    @State private var isLifted = false
    @GestureState private var isHoldAndDragActive = false
    
    let autoScrollTimer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()
    
    private func updateReorder(translationHeight: CGFloat) {
        let totalTranslation = currentDragTranslation + accumulatedAutoScroll
        dragReorderTranslation = totalTranslation
        
        let trackSpacing: CGFloat = 4
        let totalTrackHeight = trackHeight + trackSpacing
        
        let trackDelta = Int(round(translationHeight / totalTrackHeight))
        let rawTargetTrackIndex = initialTrackIndex + trackDelta
        var targetTrackIndex = rawTargetTrackIndex
        
        if initialTrackIndex <= 1 {
            targetTrackIndex = min(max(0, rawTargetTrackIndex), 1)
        } else if initialTrackIndex == 2 {
            targetTrackIndex = 2
        } else if initialTrackIndex == 3 {
            targetTrackIndex = 3
        }
        
        if targetTrackIndex != clip.trackType {
            viewModel.moveClip(id: clip.id, toTrack: targetTrackIndex)
        }
        
        let thumbWidth = max(trackHeight - 4, 10)
        let virtualCenterX = (CGFloat(initialIndex) * thumbWidth) + totalTranslation + (thumbWidth / 2)
        
        viewModel.handleCompressedReorderDrag(
            clipID: clip.id,
            trackType: clip.trackType,
            virtualCenterX: virtualCenterX,
            thumbWidth: thumbWidth
        )
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
        
        let thumbWidth = max(trackHeight - 4, 10)
        let isCompressed = viewModel.draggedClipID != nil
        let displayWidth = isCompressed ? thumbWidth : max(0, currentWidth)
        
        let baseOffset = isCompressed 
            ? (isDragged ? (CGFloat(initialIndex) * thumbWidth + dragReorderTranslation) : (CGFloat(index) * thumbWidth))
            : (isDragged ? (initialStartTime * pointsPerSecond + dragReorderTranslation) : (clip.startTime * pointsPerSecond))
            
        let visualOffset: CGFloat = 0
        
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
            .contentShape(Rectangle())
            .simultaneousGesture(
                TapGesture().onEnded {
                    // Toggle selection — deselect if already selected
                    viewModel.selectedClipID = (viewModel.selectedClipID == clip.id) ? nil : clip.id
                }
            )
            .highPriorityGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
                    .onChanged { value in
                        switch value {
                        case .first(true):
                            break // Do nothing during the 3-second hold tracking phase
                        case .second(true, let dragValue):
                            if !isLifted {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                    isLifted = true
                                    viewModel.selectedClipID = clip.id
                                    
                                    if viewModel.draggedClipID != clip.id {
                                        viewModel.draggedClipID = clip.id
                                        initialStartTime = clip.startTime
                                        initialIndex = index
                                        initialTrackIndex = clip.trackType
                                        viewModel.currentTime = 0
                                        viewModel.syncScroll()
                                    }
                                }
                            }
                            
                            guard let value = dragValue else { return }
                            
                            isDraggingReorder = true
                            currentDragTranslation = value.translation.width
                            currentDragTranslationHeight = value.translation.height
                            
                            let globalX = value.location.x
                            let screenWidth = (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.width ?? 400
                            isAutoScrollingLeft = globalX < 80
                            isAutoScrollingRight = globalX > screenWidth - 80
                            
                            updateReorder(translationHeight: currentDragTranslationHeight)
                        default:
                            break
                        }
                    }
                    .updating($isHoldAndDragActive) { value, state, _ in
                        state = true
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isLifted = false
                        }
                        
                        isDraggingReorder = false
                        isAutoScrollingLeft = false
                        isAutoScrollingRight = false
                        
                        if viewModel.draggedClipID != nil {
                            viewModel.snapshotForUndo()
                            viewModel.draggedClipID = nil
                            dragReorderTranslation = 0
                            currentDragTranslation = 0
                            accumulatedAutoScroll = 0
                            viewModel.cleanupEmptyTracks()
                            Task { await viewModel.rebuildComposition(); viewModel.save() }
                        }
                    }
            )
            .onChange(of: isHoldAndDragActive) { _, active in
                if !active {
                    // Reset if the gesture cancelled mid-way (e.g. lifted finger early)
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                        isLifted = false
                    }
                    isDraggingReorder = false
                    isAutoScrollingLeft = false
                    isAutoScrollingRight = false
                    
                    if viewModel.draggedClipID != nil {
                        viewModel.draggedClipID = nil
                        dragReorderTranslation = 0
                        currentDragTranslation = 0
                        accumulatedAutoScroll = 0
                        viewModel.cleanupEmptyTracks()
                    }
                }
            }
            
            // ── Trim Handles (high-priority drag, only when selected) ───────
            if isSelected && !isLifted {
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
        .padding(.trailing, 6)
        .frame(width: displayWidth, height: max(trackHeight - 4, 10))
        .offset(x: baseOffset + dragOffsetLeft + visualOffset)
        .scaleEffect(isLifted ? 1.05 : 1.0)
        .shadow(color: isLifted ? .black.opacity(0.5) : .clear, radius: isLifted ? 8 : 0, x: 0, y: isLifted ? 5 : 0)
        .zIndex(isLifted ? 100 : (isDragged ? 50 : (isSelected ? 20 : 0)))
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
            
            let scrollSpeed: CGFloat = 20
            accumulatedAutoScroll += direction * scrollSpeed
            
            // Smoothly scroll the timeline independent of the clip's exact position
            let newTime = viewModel.currentTime + (direction * scrollSpeed / pointsPerSecond)
            viewModel.currentTime = max(0, newTime)
            viewModel.syncScroll()
            
            if isDraggingLeft {
                updateTrimLeft()
            } else if isDraggingRight {
                updateTrimRight()
            } else if isDraggingReorder {
                updateReorder(translationHeight: currentDragTranslationHeight)
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
