import SwiftUI
import AVKit

// MARK: - Fullscreen Player

struct FullscreenPlayerView: View {
    @Bindable var viewModel: TimelineEditorViewModel
    @Binding var isPresented: Bool

    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 1
    @State private var isDraggingSlider = false
    @State private var showControls = true
    @State private var hideControlsTask: Task<Void, Never>? = nil
    @State private var timeObserver: Any? = nil

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            AVPlayerView(
                player: viewModel.player,
                videoGravity: .resizeAspect
            )
            .ignoresSafeArea()
            .onTapGesture {
                toggleControls()
            }

            if showControls {
                VStack {
                    // Top: Close button
                    HStack {
                        Spacer()
                        Button(action: { isPresented = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white)
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .padding(.trailing, 20)
                        .padding(.top, 40)
                    }

                    Spacer()

                    // Bottom: controls
                    VStack(spacing: 12) {
                        // Progress bar
                        Slider(
                            value: Binding(
                                get: { currentTime },
                                set: { val in
                                    currentTime = val
                                    viewModel.scrub(to: val, exact: false)
                                    resetHideTimer()
                                }
                            ),
                            in: 0...max(duration, 0.01)
                        )
                        .tint(.white)

                        // Time labels + Play button
                        HStack(spacing: 16) {
                            Text(formatTime(currentTime))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)

                            Spacer()

                            Button(action: {
                                viewModel.togglePlayback()
                                isPlaying = viewModel.isPlaying
                                resetHideTimer()
                            }) {
                                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 52, height: 52)
                                    .background(.ultraThinMaterial, in: Circle())
                            }

                            Spacer()

                            Text(formatTime(duration))
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 60)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 200)
                        .allowsHitTesting(false),
                        alignment: .bottom
                    )
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: showControls)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(true)
        .onAppear {
            syncState()
            startTimeObserver()
            scheduleHideControls()
        }
        .onDisappear {
            stopTimeObserver()
            hideControlsTask?.cancel()
        }
    }

    private func toggleControls() {
        withAnimation { showControls.toggle() }
        if showControls { resetHideTimer() }
    }

    private func resetHideTimer() {
        hideControlsTask?.cancel()
        scheduleHideControls()
    }

    private func scheduleHideControls() {
        hideControlsTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if !isDraggingSlider {
                    withAnimation { showControls = false }
                }
            }
        }
    }

    private func syncState() {
        isPlaying = viewModel.isPlaying
        currentTime = viewModel.currentTime
        if let item = viewModel.player.currentItem {
            let d = item.duration.seconds
            duration = d.isFinite && d > 0 ? d : viewModel.timeline.totalDuration
        } else {
            duration = viewModel.timeline.totalDuration
        }
    }

    private func startTimeObserver() {
        let interval = CMTime(seconds: 1.0 / 30.0, preferredTimescale: 600)
        timeObserver = viewModel.player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard !isDraggingSlider else { return }
            currentTime = time.seconds.isFinite ? time.seconds : 0
            isPlaying = viewModel.player.rate > 0
        }
    }

    private func stopTimeObserver() {
        if let obs = timeObserver {
            viewModel.player.removeTimeObserver(obs)
            timeObserver = nil
        }
    }

    private func formatTime(_ t: Double) -> String {
        guard t.isFinite else { return "00:00" }
        let m = Int(t) / 60
        let s = Int(t) % 60
        return String(format: "%02d:%02d", m, s)
    }
}
