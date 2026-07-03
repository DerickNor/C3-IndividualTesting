import SwiftUI
import Combine



@available(iOS 18.0, *)
struct TimelineEditorView: View {
    @State private var viewModel: TimelineEditorViewModel
    // Tab state and tooltip control
    @State private var selectedTab: EditorTool = .edit
    @State private var activeTooltip: EditorTool? = nil
    @State private var showDeleteAlert = false
    @State private var showSplitFeedback = false
    
    @Environment(\.dismiss) private var dismiss
    
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
                
            }
            .simultaneousGesture(
                TapGesture().onEnded {
                    if activeTooltip != nil {
                        withAnimation { activeTooltip = nil }
                    }
                }
            )
            
            // Split flash overlay — briefly appears when a cut is performed
            if showSplitFeedback {
                Color.white.opacity(0.18)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .transition(.opacity)
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
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 17, weight: .semibold))
                    }
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    // Export logic placeholder
                }) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .buttonBorderShape(.circle)
            }
            
            ToolbarItemGroup(placement: .bottomBar) {
                ControlGroup {
                    Menu {
                        Button(action: { selectedTab = .ai; withAnimation { activeTooltip = nil } }) {
                            Label("Auto-Cut", systemImage: "scissors")
                        }
                        Button(action: { selectedTab = .ai; withAnimation { activeTooltip = nil } }) {
                            Label("Auto-Sequence", systemImage: "film")
                        }
                        Menu {
                            Button(action: { selectedTab = .ai; withAnimation { activeTooltip = nil } }) {
                                Label("Auto Generate", systemImage: "wand.and.stars")
                            }
                            Button(action: { selectedTab = .ai; withAnimation { activeTooltip = nil } }) {
                                Label("Input Script", systemImage: "doc.plaintext")
                            }
                        } label: {
                            Label("Auto-Caption", systemImage: "captions.bubble")
                        }
                    } label: {
                        Label("AI", systemImage: "sparkles")
                    }
                    
                    Menu {
                        Button(action: {
                            withAnimation { activeTooltip = nil }
                            performSplit()
                        }) {
                            Label("Split", systemImage: "scissors.badge.ellipsis")
                        }
                        Button(action: { selectedTab = .edit; withAnimation { activeTooltip = nil } }) {
                            Label("Volume", systemImage: "speaker.wave.2.fill")
                        }
                    } label: {
                        Label("Edit", systemImage: "scissors")
                    }
                    
                    Button(action: {
                        withAnimation { activeTooltip = nil }
                        selectedTab = .audio
                    }) {
                        Label("Audio", systemImage: "waveform")
                    }
                    
                    Menu {
                        Button(action: { selectedTab = .text; withAnimation { activeTooltip = nil } }) {
                            Label("Text", systemImage: "textformat")
                        }
                        Button(action: { selectedTab = .overlay; withAnimation { activeTooltip = nil } }) {
                            Label("Overlay", systemImage: "square.on.square")
                        }
                        Button(action: { selectedTab = .captions; withAnimation { activeTooltip = nil } }) {
                            Label("Captions", systemImage: "captions.bubble")
                        }
                        Button(role: .destructive, action: {
                            if viewModel.selectedClipID != nil {
                                showDeleteAlert = true
                            }
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Label("More", systemImage: "ellipsis.circle")
                    }
                }
                
                Spacer()
            }
        }
    }
    
    // MARK: - Split Action
    private func performSplit() {
        let splitTime = viewModel.currentTime

        // Hanya boleh split jika ada scene yang dipilih
        guard let selectedID = viewModel.selectedClipID,
              let selectedClip = viewModel.timeline.clips.first(where: { $0.id == selectedID }) else { return }

        // Playhead harus berada di dalam clip yang dipilih
        guard splitTime > selectedClip.startTime + 0.1,
              splitTime < selectedClip.startTime + selectedClip.duration - 0.1 else { return }

        
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        
        viewModel.splitClip(at: splitTime)
        
        // Brief visual flash to confirm split
        withAnimation(.easeIn(duration: 0.05)) {
            showSplitFeedback = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            withAnimation(.easeOut(duration: 0.2)) {
                showSplitFeedback = false
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
