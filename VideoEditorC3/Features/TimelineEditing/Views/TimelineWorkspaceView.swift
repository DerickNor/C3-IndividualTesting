import SwiftUI

struct TimelineWorkspaceView: View {
    @Bindable var viewModel: TimelineEditorViewModel
    let pointsPerSecond: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Preview Area (Top Half)
            ZStack {
                Color(white: 0.06) // Background behind the canvas
                
                // Actual Video Canvas
                ZStack {
                    Color.black
                    
                    // Placeholder for AVPlayer
                    VStack(spacing: 12) {
                        Image(systemName: "play.tv")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("Preview Canvas")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
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
                            VStack(spacing: 8) {
                                ForEach(TrackType.allCases, id: \.self) { trackType in
                                        ZStack(alignment: .leading) {
                                            // Track Icon (positioned to the left of 00:00)
                                            ZStack {
                                                Circle()
                                                    .fill(Color.black.opacity(0.6))
                                                    .frame(width: 28, height: 28)
                                                
                                                trackIcon(for: trackType)
                                            }
                                            .offset(x: -48) // Move it 48 points to the left of the track start
                                            .zIndex(2) // Ensure it appears above other elements if they overlap
                                            
                                            // Empty Scene Background for Track
                                            let isTimelineEmpty = viewModel.timeline.clips.isEmpty
                                            let trackWidth = isTimelineEmpty ? 120.0 : max(geometry.size.width, viewModel.timeline.totalDuration * pointsPerSecond)
                                            Rectangle()
                                                .fill(Color(.systemGray5)) // Lighter gray for more contrast
                                                .frame(width: trackWidth, height: trackHeight(for: trackType))
                                                .cornerRadius(4)
                                            
                                            let trackClips = viewModel.timeline.clips.filter { $0.trackType == trackType }
                                            
                                            // Clips for this specific track
                                            ForEach(trackClips) { clip in
                                                TimelineClipView(clip: clip, pointsPerSecond: pointsPerSecond, trackHeight: trackHeight(for: trackType))
                                            }
                                            
                                            // "Add" button for all tracks
                                            let maxTime = trackClips.map { $0.startTime + $0.duration }.max() ?? 0
                                            Button(action: {
                                                // Placeholder for adding a new clip
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
                                                .frame(width: 120, height: trackHeight(for: trackType) - 4)
                                            }
                                            // Place at the end of the last clip, or at 00:00 if empty
                                            .offset(x: maxTime * pointsPerSecond + (maxTime == 0 ? 0 : 8))
                                        }
                                    }
                                }
                        }
                        .background(
                            GeometryReader { proxy in
                                Color.clear.preference(
                                    key: ScrollOffsetPreferenceKey.self,
                                    value: proxy.frame(in: .named("TimelineScroll")).minX
                                )
                            }
                        )
                        .padding(.vertical, 16)
                        // This padding pushes the start of the timeline to the center of the screen
                        .padding(.horizontal, halfWidth)
                    }
                    .coordinateSpace(name: "TimelineScroll")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { minX in
                        let offset = halfWidth - minX
                        let time = max(0, offset / pointsPerSecond)
                        if !viewModel.isPlaying {
                            viewModel.currentTime = time
                        }
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
            return 45
        case .audio:
            return 35
        case .text:
            return 30
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

// Preference key to track scroll position
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
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
                if second % 2 == 0 { // 00:00, 00:02, etc
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
        }
        .frame(width: width, alignment: .leading)
    }
    
    private func formatTimeWithoutMs(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
