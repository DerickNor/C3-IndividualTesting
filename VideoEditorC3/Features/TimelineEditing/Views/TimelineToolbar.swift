import SwiftUI

@available(iOS 18.0, *)
struct TimelineToolbar: ToolbarContent {
    @Bindable var viewModel: TimelineEditorViewModel
    @Binding var selectedTab: EditorTool
    @Binding var activeTooltip: EditorTool?
    
    let onDismiss: () -> Void
    let onSplit: () -> Void
    let onDelete: () -> Void
    
    var body: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button(action: onDismiss) {
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
                        onSplit()
                    }) {
                        Label("Split", systemImage: "scissors.badge.ellipsis")
                    }
                    Button(action: { selectedTab = .edit; withAnimation { activeTooltip = nil } }) {
                        Label("Volume", systemImage: "speaker.wave.2.fill")
                    }
                } label: {
                    Label("Edit", systemImage: "scissors")
                }
                
                Menu {
                    Button(action: {
                        withAnimation { activeTooltip = nil }
                        selectedTab = .audio
                        viewModel.isShowingAudioImporter = true
                    }) {
                        Label("Add Audio", systemImage: "plus.circle")
                    }
                } label: {
                    Label("Audio", systemImage: "waveform")
                }
                
                Menu {
                    Button(action: { 
                        selectedTab = .text
                        withAnimation { activeTooltip = nil }
                        viewModel.addTextClip()
                    }) {
                        Label("Add Text", systemImage: "plus.circle")
                    }
                    Button(action: { selectedTab = .overlay; withAnimation { activeTooltip = nil } }) {
                        Label("Overlay", systemImage: "square.on.square")
                    }
                    Button(action: { selectedTab = .captions; withAnimation { activeTooltip = nil } }) {
                        Label("Captions", systemImage: "captions.bubble")
                    }
                    Button(role: .destructive, action: onDelete) {
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
