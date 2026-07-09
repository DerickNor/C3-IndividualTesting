import SwiftUI

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

    @ViewBuilder
    private var trackIcon: some View {
        if trackType == 0 {
            Button(action: {
                viewModel.isMuted.toggle()
            }) {
                Image(systemName: viewModel.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
        } else {
            Image(systemName: "square.on.square.dashed")
                .foregroundColor(.white)
                .font(.system(size: 11, weight: .bold))
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
            }

            // Clips are now rendered globally in TimelineWorkspaceView to preserve identity during cross-track drag
            
            // Transition markers are now rendered globally above the clips

            // Add button placeholder when track is empty
            if trackType == 0 && trackClips.isEmpty {
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
                                Text("Add Scene")
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
                                    viewModel.pendingAddTrack = trackType
                                    viewModel.isShowingVideoPicker = true
                                },
                                actionFiles: {
                                    activeAddMenuTrack = nil
                                    viewModel.pendingAddTrack = trackType
                                    showingFileImporter = true
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
        .frame(height: trackHeight)
        .animation(nil, value: trackWidth)
    }
}
