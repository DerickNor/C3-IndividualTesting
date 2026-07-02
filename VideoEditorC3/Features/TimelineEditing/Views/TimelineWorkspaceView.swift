import SwiftUI
import PhotosUI

struct TimelineWorkspaceView: View {
    @Bindable var viewModel: TimelineEditorViewModel
    let pointsPerSecond: CGFloat
    
    @State private var selectedVideoItems: [PhotosPickerItem] = []
    @State private var scrollPosition = ScrollPosition(edge: .leading)
    @State private var wasPlayingBeforeScroll = false
    @State private var showingFileImporter = false
    @State private var activeAddMenuTrack: TrackType? = nil
    
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
                            viewModel.undo()
                        }) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 18))
                                .foregroundColor(viewModel.canUndo ? .primary : .gray)
                                .frame(width: 44, height: 44)
                        }
                        .disabled(!viewModel.canUndo)
                        
                        Button(action: {
                            viewModel.redo()
                        }) {
                            Image(systemName: "arrow.uturn.forward")
                                .font(.system(size: 18))
                                .foregroundColor(viewModel.canRedo ? .primary : .gray)
                                .frame(width: 44, height: 44)
                        }
                        .disabled(!viewModel.canRedo)
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
                                        trackHeight: trackHeight(for: trackType),
                                        showingFileImporter: $showingFileImporter,
                                        activeAddMenuTrack: $activeAddMenuTrack
                                    )
                                }
                            }
                        }
                        .padding(.vertical, 16)
                        // This padding pushes the start of the timeline to the center of the screen
                        .padding(.horizontal, halfWidth)
                    }
                    .scrollPosition($scrollPosition)
                    .onScrollPhaseChange { oldPhase, newPhase in
                        if newPhase == .interacting {
                            if viewModel.isPlaying {
                                wasPlayingBeforeScroll = true
                                viewModel.pause()
                            }
                        } else if newPhase == .idle {
                            if wasPlayingBeforeScroll {
                                wasPlayingBeforeScroll = false
                                viewModel.play()
                            }
                        }
                    }
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
                        
                    // Fixed Add Buttons (Right aligned)
                    VStack(alignment: .trailing, spacing: 8) {
                        Spacer().frame(height: 35) // Adjusted upward slightly for optical alignment with the track
                        ForEach(TrackType.allCases, id: \.self) { trackType in
                            let trackHeight = trackHeight(for: trackType)
                            let hasClips = !viewModel.timeline.clips.filter { $0.trackType == trackType }.isEmpty
                            if hasClips {
                                Button(action: {
                                    activeAddMenuTrack = (activeAddMenuTrack == trackType) ? nil : trackType
                                }) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.white)
                                            .frame(width: 26, height: 26)
                                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                                        Image(systemName: "plus")
                                            .font(.system(size: 14, weight: .bold))
                                            .foregroundColor(.black)
                                    }
                                    .frame(width: 44, height: trackHeight)
                                }
                                .overlay(alignment: .leading) {
                                    if activeAddMenuTrack == trackType {
                                        TinyAddMenu(
                                            actionPhoto: {
                                                activeAddMenuTrack = nil
                                                if trackType == .video { viewModel.isShowingVideoPicker = true }
                                            },
                                            actionFiles: {
                                                activeAddMenuTrack = nil
                                                if trackType == .video { showingFileImporter = true }
                                            }
                                        )
                                        .offset(x: -140) // Place directly left of the + button
                                        .zIndex(50)
                                    }
                                }
                            } else {
                                // Empty space if this track has no clips to maintain vertical alignment
                                Spacer().frame(height: trackHeight)
                            }
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    
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
                .onTapGesture {
                    // Dismiss menu when tapping outside
                    if activeAddMenuTrack != nil {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            activeAddMenuTrack = nil
                        }
                    }
                }
            }
        }
        .photosPicker(isPresented: $viewModel.isShowingVideoPicker, selection: $selectedVideoItems, matching: .videos)
        .onChange(of: selectedVideoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            viewModel.addVideoClips(from: newItems)
            selectedVideoItems = [] // Reset for next selection
        }
        .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.movie, .video, .mpeg4Movie, .quickTimeMovie], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                viewModel.addVideoClips(fromURLs: urls)
            case .failure(let error):
                print("Error selecting files: \(error.localizedDescription)")
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
            return 60
        case .audio:
            return 45
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
            Image(systemName: "waveform")
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
            ForEach(Array(stride(from: 0, through: seconds, by: 2)), id: \.self) { second in
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
    
    @Binding var showingFileImporter: Bool
    @Binding var activeAddMenuTrack: TrackType?
    private var trackClips: [Clip] {
        viewModel.timeline.clips.filter { $0.trackType == trackType }.sorted { $0.startTime < $1.startTime }
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
                Image(systemName: "waveform")
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
            if trackClips.isEmpty {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .frame(width: trackWidth, height: trackHeight)
                    .onTapGesture {
                        viewModel.selectedClipID = nil
                    }
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
            
            // Transition markers (link chain) between scenes
            ForEach(0..<trackClips.count, id: \.self) { i in
                if i < trackClips.count - 1 {
                    let linkTime = trackClips[i].startTime + trackClips[i].duration
                    ZStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white)
                            .frame(width: 20, height: 20)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        Image(systemName: "link")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.black)
                    }
                    .offset(x: linkTime * pointsPerSecond - 10)
                    .zIndex(10)
                }
            }

            // Add button placed immediately after last clip
            if trackClips.isEmpty {
                HStack(spacing: 0) {
                    Spacer()
                        .frame(width: ownMaxTime * pointsPerSecond + addButtonGap)
                    
                    Button(action: {
                        activeAddMenuTrack = (activeAddMenuTrack == trackType) ? nil : trackType
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
                    .buttonStyle(DimmingButtonStyle())
                    .overlay(alignment: .top) {
                        if activeAddMenuTrack == trackType {
                            TinyAddMenu(
                                actionPhoto: {
                                    activeAddMenuTrack = nil
                                    if trackType == .video { viewModel.isShowingVideoPicker = true }
                                },
                                actionFiles: {
                                    activeAddMenuTrack = nil
                                    if trackType == .video { showingFileImporter = true }
                                }
                            )
                            .offset(y: -80) // Centered cleanly above the block button
                            .zIndex(50)
                        }
                    }
                }
                .animation(nil, value: ownMaxTime)
            }
        }
        .animation(nil, value: trackWidth)
    }
}

struct TinyAddMenu: View {
    let actionPhoto: () -> Void
    let actionFiles: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: actionPhoto) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 12))
                    Text("Photo Album")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Divider()
            
            Button(action: actionFiles) {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                    Text("Files")
                        .font(.system(size: 12, weight: .medium))
                    Spacer()
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 130)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
}

struct DimmingButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
