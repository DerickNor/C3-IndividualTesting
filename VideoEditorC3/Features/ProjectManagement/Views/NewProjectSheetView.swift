import SwiftUI

struct NewProjectSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    // Callbacks to pass data back to the parent
    let onCreate: (String, CanvasSize) -> Void
    
    // Local state for the form
    @State private var projectTitle: String = ""
    @State private var selectedCanvasSize: CanvasSize = .story
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Project Details")) {
                    TextField("Project Title", text: $projectTitle)
                        .autocorrectionDisabled()
                }
                
                Section(header: Text("Canvas Size"), footer: Text("Choose the aspect ratio that best fits your destination platform (e.g., 9:16 for TikTok/IG Story).")) {
                    Picker("Format", selection: $selectedCanvasSize) {
                        ForEach(CanvasSize.allCases, id: \.self) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .pickerStyle(.menu) // Native dropdown style
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(uiColor: .systemGray5))
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        let trimmedTitle = projectTitle.trimmingCharacters(in: .whitespaces)
                        let finalTitle = trimmedTitle.isEmpty ? "Untitled Project" : trimmedTitle
                        onCreate(finalTitle, selectedCanvasSize)
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                    }
                }
            }
        }
    }
}

#Preview {
    NewProjectSheetView { _, _ in }
}
