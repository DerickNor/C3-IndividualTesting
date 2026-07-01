 import Foundation
import Observation

@Observable
final class ProjectListViewModel {
    var projects: [VideoProject] = []
    
    init() {
        loadMockProjects()
    }
    
    func createNewProject(title: String, canvasSize: CanvasSize) -> VideoProject {
        let newProject = VideoProject(title: title, canvasSize: canvasSize)
        // Add to the beginning of the list
        projects.insert(newProject, at: 0)
        return newProject
    }
    
    func deleteProject(_ project: VideoProject) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects.remove(at: index)
        }
    }
    
    func duplicateProject(_ project: VideoProject) {
        var duplicated = project
        duplicated.title = "\(project.title) (Copy)"
        duplicated.lastModifiedDate = Date()
        let newProject = VideoProject(title: duplicated.title, creationDate: Date(), lastModifiedDate: Date(), thumbnailData: duplicated.thumbnailData, canvasSize: duplicated.canvasSize)
        projects.insert(newProject, at: 0)
    }
    
    func renameProject(_ project: VideoProject, newTitle: String) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].title = newTitle
            projects[index].lastModifiedDate = Date()
        }
    }
    
    private func loadMockProjects() {
        // Generate some dummy projects for initial UI testing
        let dummyProjects = [
            VideoProject(title: "Vlog Bali", creationDate: Date().addingTimeInterval(-86400 * 2), lastModifiedDate: Date().addingTimeInterval(-3600)),
            VideoProject(title: "Cinematic B-Roll", creationDate: Date().addingTimeInterval(-86400 * 5), lastModifiedDate: Date().addingTimeInterval(-86400 * 1)),
            VideoProject(title: "Tutorial Swift", creationDate: Date().addingTimeInterval(-86400 * 10), lastModifiedDate: Date().addingTimeInterval(-86400 * 8))
        ]
        
        // Sort by last modified date descending
        self.projects = dummyProjects.sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate })
    }
}
