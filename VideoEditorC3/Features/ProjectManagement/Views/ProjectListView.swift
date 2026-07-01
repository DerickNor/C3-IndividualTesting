import SwiftUI

struct ProjectListView: View {
    @State private var viewModel = ProjectListViewModel()
    @State private var showingNewProjectSheet = false
    @State private var navPath = NavigationPath()
    
    // Rename state
    @State private var showingRenameAlert = false
    @State private var renameProjectTitle = ""
    @State private var projectToRename: VideoProject?
    
    // Search state
    @State private var searchText = ""
    
    var filteredProjects: [VideoProject] {
        if searchText.isEmpty {
            return viewModel.projects
        } else {
            return viewModel.projects.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    // Grid configuration for nice thumbnail display
    let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
    ]
    
    var body: some View {
        NavigationStack(path: $navPath) {
            ScrollView {
                if viewModel.projects.isEmpty {
                    emptyStateView
                } else if filteredProjects.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No results for \"\(searchText)\"")
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(filteredProjects) { project in
                            NavigationLink(value: project) {
                                ProjectCardView(
                                    project: project,
                                    onRename: {
                                        projectToRename = project
                                        renameProjectTitle = project.title
                                        showingRenameAlert = true
                                    },
                                    onDuplicate: {
                                        withAnimation {
                                            viewModel.duplicateProject(project)
                                        }
                                    },
                                    onDelete: {
                                        withAnimation {
                                            viewModel.deleteProject(project)
                                        }
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("My Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingNewProjectSheet = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search projects...")
            .sheet(isPresented: $showingNewProjectSheet) {
                NewProjectSheetView { title, canvasSize in
                    withAnimation {
                        let newProject = viewModel.createNewProject(title: title, canvasSize: canvasSize)
                        
                        // Push immediately to the timeline editor
                        // We use asyncAfter slightly to avoid NavigationStack issues while a sheet is dismissing
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            navPath.append(newProject)
                        }
                    }
                }
                .presentationDetents([.height(350)])
                .presentationDragIndicator(.visible)
            }
            .alert("Rename Project", isPresented: $showingRenameAlert) {
                TextField("New Title", text: $renameProjectTitle)
                Button("Cancel", role: .cancel) { }
                Button("Save") {
                    if let project = projectToRename, !renameProjectTitle.trimmingCharacters(in: .whitespaces).isEmpty {
                        withAnimation {
                            viewModel.renameProject(project, newTitle: renameProjectTitle)
                        }
                    }
                }
            }
            .navigationDestination(for: VideoProject.self) { project in
                TimelineEditorView(project: project) { updatedProject in
                    viewModel.updateProject(updatedProject)
                }
                .id(project.id)
            }
        }
    }
    
    // MARK: - Subviews
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Projects Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create a new project to start editing your videos.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                showingNewProjectSheet = true
            }) {
                Text("Create New Project")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 400)
    }
}

// MARK: - Helper View for Grid Cell
struct ProjectCardView: View {
    let project: VideoProject
    let onRename: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thumbnail Area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .aspectRatio(16/9, contentMode: .fit)
                
                Image(systemName: "play.rectangle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.gray)
            }
            
            // Title, Date & Menu
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.title)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text(project.lastModifiedDate, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                Menu {
                    Button(action: onRename) {
                        Label("Rename", systemImage: "pencil")
                    }
                    Button(action: onDuplicate) {
                        Label("Duplicate", systemImage: "plus.square.on.square")
                    }
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .padding(4)
                }
            }
            .padding(.horizontal, 4)
        }
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    ProjectListView()
}
