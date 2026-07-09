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
                    .equatable()
                
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
            TimelineToolbar(
                viewModel: viewModel,
                selectedTab: $selectedTab,
                activeTooltip: $activeTooltip,
                onDismiss: { dismiss() },
                onSplit: { performSplit() },
                onDelete: {
                    if viewModel.selectedClipID != nil {
                        viewModel.pause() // Pause player to free up main thread
                        showDeleteAlert = true
                    }
                }
            )
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
