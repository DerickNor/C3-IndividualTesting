import SwiftUI
import PhotosUI

struct TimelineWorkspaceView: View {
    @Bindable var viewModel: TimelineEditorViewModel
    let pointsPerSecond: CGFloat
    
    @State private var selectedVideoItems: [PhotosPickerItem] = []
    @State private var scrollPosition = ScrollPosition(edge: .leading)
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Preview Area (Top Half)
            ZStack {
                Color(white: 0.06) // Background behind the canvas
                
                // Actual Video Canvas
                ZStack {
                    Color.black
                    
                    // Placeholder for AVPlayer
                    // Native AVPlayer without default controls
                    AVPlayerView(player: viewModel.player)
                }
                .aspectRatio(viewModel.project.canvasSize.aspectRatio, contentMode: .fit)
                .clipped()
            }
            .frame(height: 350)
            
            // 2. Toolbar & Controls
            ZStack(alignment: .center) {
                // Left: Fullscreen Canvas
                HStack {
                    Button(action: {
                        // Fullscreen preview
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 25, height: 25)
                    }
                    Spacer()
                }
                
                // Center: Play / Pause
                Button(action: {
                    viewModel.togglePlayback()
                }) {
                    Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                        .frame(width: 44, height: 44)
                }
                
                // Right: Undo & Redo
                HStack {
                    Spacer()
                    HStack(spacing: 2) {
                        Button(action: {
                            // Undo
                        }) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                        }
                        .disabled(true) // Disable until logic is ready
                        
                        Button(action: {
                            // Redo
                        }) {
                            Image(systemName: "arrow.uturn.forward")
                                .font(.system(size: 18))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                        }
                        .disabled(true)
                    }
                }
            }
            .zIndex(1)
            .frame(height: 25)
            .padding(.horizontal, 4)
            .padding(.top, 10)
            .padding(.bottom, 10)
            .background(Color(white: 0.06))
            
            // 3. Timeline Scroller
            GeometryReader { geometry in
                let halfWidth = geometry.size.width / 2
                
                ZStack(alignment: .top) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 4) { // 4pt gap separates Ruler from Clips
                            // Ruler (Now acts as the header section)
                            TimelineRulerView(totalDuration: viewModel.timeline.totalDuration, pointsPerSecond: pointsPerSecond)
                                .frame(height: 24)
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(TrackType.allCases, id: \.self) { trackType in
                                    TrackRowView(
                                        trackType: trackType,
                                        viewModel: viewModel,
                                        pointsPerSecond: pointsPerSecond,
                                        trackHeight: trackHeight(for: trackType)
                                    )
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        // This padding pushes the start of the timeline to the center of the screen
                        .padding(.horizontal, halfWidth)
                    }
                    .scrollPosition($scrollPosition)
                    .onScrollGeometryChange(for: CGFloat.self) { geo in
                        geo.contentOffset.x
                    } action: { _, offsetX in
                        // Only update time from user-driven scroll (not during playback)
                        guard !viewModel.isPlaying else { return }
                        let time = max(0, offsetX / pointsPerSecond)
                        viewModel.currentTime = time
                        viewModel.scrub(to: time)
                    }
                    .onChange(of: viewModel.currentTime) { _, newTime in
                        // Auto-scroll the timeline to follow the playhead during playback
                        guard viewModel.isPlaying else { return }
                        scrollPosition = ScrollPosition(x: newTime * pointsPerSecond)
                    }
                    .onChange(of: viewModel.scrollSyncToken) { _, _ in
                        // Force scroll to currentTime (e.g. after trim completes)
                        scrollPosition = ScrollPosition(x: viewModel.currentTime * pointsPerSecond)
                    }
                    
                    // Fixed Playhead indicator (White line) in the center
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 2)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        // The playhead spans the height of the timeline area
                        .frame(maxHeight: .infinity)
                        .padding(.top, 16) // Start from ruler level
                    
                    // Floating Total Time Badge (Top Left)
                    HStack {
                        VStack(spacing: 2) {
                            Text("\(formatTimeWithoutMs(viewModel.currentTime)) / \(formatTimeWithoutMs(viewModel.timeline.totalDuration))")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.leading, 12)
                        .padding(.trailing, 32) // Extra width for smooth gradient fade
                        .frame(height: 24) // Match Ruler height exactly
                        .background(
                            LinearGradient(
                                gradient: Gradient(stops: [
                                    .init(color: Color(.systemGray6), location: 0),
                                    .init(color: Color(.systemGray6), location: 0.75),
                                    .init(color: Color(.systemGray6).opacity(0), location: 1)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        
                        Spacer()
                    }
                    .padding(.top, 14) // Nudged up slightly for visual alignment
                }
                .background(Color(.systemGray6))
            }
        }
        .photosPicker(isPresented: $viewModel.isShowingVideoPicker, selection: $selectedVideoItems, matching: .videos)
        .onChange(of: selectedVideoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            viewModel.addVideoClips(from: newItems)
            selectedVideoItems = [] // Reset for next selection
        }
    }
    
    // Format TimeInterval to mm:ss.ms
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }
    
    // Format TimeInterval to mm:ss
    private func formatTimeWithoutMs(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // Determine the height of each track layer
    private func trackHeight(for type: TrackType) -> CGFloat {
        switch type {
        case .video:
            return 50
        case .audio:
            return 40
        case .text:
            return 35
        }
    }
    
    @ViewBuilder
    private func trackIcon(for type: TrackType) -> some View {
        switch type {
        case .video:
            Button(action: {
                viewModel.isMuted.toggle()
            }) {
                Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .bold))
            }
        case .audio:
            Image(systemName: "music.note")
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .bold))
        case .text:
            Image(systemName: "textformat")
                .foregroundColor(.white)
                .font(.system(size: 14, weight: .bold))
        }
    }
}


// The ruler view showing seconds
struct TimelineRulerView: View {
    let totalDuration: TimeInterval
    let pointsPerSecond: CGFloat
    
    var body: some View {
        let width = totalDuration * pointsPerSecond
        let seconds = Int(totalDuration)
        
        ZStack(alignment: .leading) {
            ForEach(0...seconds, id: \.self) { second in
                VStack(spacing: 2) {
                    Text(formatTimeWithoutMs(TimeInterval(second)))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 1, height: 6)
                    Spacer()
                }
                .frame(width: 40) // Give text room to breathe
                .offset(x: CGFloat(second) * pointsPerSecond - 20)
            }
        }
        .frame(width: width, alignment: .leading)
    }
    
    private func formatTimeWithoutMs(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// Isolated track row — each instance only sees its own trackType clips.
// Audio and Text rows are completely unaffected by Video clip changes.
struct TrackRowView: View {
    let trackType: TrackType
    let viewModel: TimelineEditorViewModel
    let pointsPerSecond: CGFloat
    let trackHeight: CGFloat

    private var trackClips: [Clip] {
        viewModel.timeline.clips.filter { $0.trackType == trackType }
    }

    // Only this track's own clips determine its width and Add button position
    private var ownMaxTime: TimeInterval {
        trackClips.map { $0.startTime + $0.duration }.max() ?? 0
    }

    private let addButtonWidth: CGFloat = 120
    private var addButtonGap: CGFloat { ownMaxTime == 0 ? 0 : 8 }

    // Background width = own clips + gap + Add button (never affected by other tracks)
    private var trackWidth: CGFloat {
        ownMaxTime * pointsPerSecond + addButtonGap + addButtonWidth
    }

    private var trackIcon: some View {
        Group {
            switch trackType {
            case .video:
                Button(action: {
                    viewModel.isMuted.toggle()
                }) {
                    Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            case .audio:
                Image(systemName: "music.note")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            case .text:
                Image(systemName: "textformat")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
            }
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Track icon badge (left of 00:00)
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 28, height: 28)
                trackIcon
            }
            .offset(x: -48)
            .zIndex(2)

            // Gray background — exactly fits clips + Add button for THIS track only
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(width: trackWidth, height: trackHeight)
                .cornerRadius(4)
                .onTapGesture {
                    viewModel.selectedClipID = nil
                }

            // Clips
            ForEach(trackClips) { clip in
                TimelineClipView(
                    clip: clip,
                    pointsPerSecond: pointsPerSecond,
                    trackHeight: trackHeight,
                    viewModel: viewModel
                )
            }

            // Add button placed immediately after last clip
            Button(action: {
                if trackType == .video {
                    viewModel.isShowingVideoPicker = true
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.3))
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                        .foregroundColor(.gray)
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .bold))
                        Text(trackType == .video ? "Add Scene" : (trackType == .audio ? "Add Audio" : "Add Text"))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.gray)
                }
                .frame(width: addButtonWidth, height: trackHeight - 4)
            }
            .offset(x: ownMaxTime * pointsPerSecond + addButtonGap)
            .animation(nil, value: ownMaxTime)
        }
        .animation(nil, value: trackWidth)
    }
}
