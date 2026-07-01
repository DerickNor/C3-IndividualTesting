import Foundation
import Observation

@Observable
final class ProjectListViewModel {
    var projects: [VideoProject] = []
    
    private let saveURL: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0].appendingPathComponent("projects.json")
    }()
    
    init() {
        loadProjects()
    }
    
    func createNewProject(title: String, canvasSize: CanvasSize) -> VideoProject {
        let newProject = VideoProject(title: title, canvasSize: canvasSize)
        projects.insert(newProject, at: 0)
        saveProjects()
        return newProject
    }
    
    func deleteProject(_ project: VideoProject) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects.remove(at: index)
            saveProjects()
        }
    }
    
    func duplicateProject(_ project: VideoProject) {
        var duplicated = project
        duplicated.title = "\(project.title) (Copy)"
        duplicated.lastModifiedDate = Date()
        let newProject = VideoProject(
            id: UUID(),
            title: duplicated.title,
            creationDate: Date(),
            lastModifiedDate: Date(),
            thumbnailData: duplicated.thumbnailData,
            canvasSize: duplicated.canvasSize,
            timeline: duplicated.timeline
        )
        projects.insert(newProject, at: 0)
        saveProjects()
    }
    
    func renameProject(_ project: VideoProject, newTitle: String) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index].title = newTitle
            projects[index].lastModifiedDate = Date()
            saveProjects()
        }
    }
    
    func updateProject(_ project: VideoProject) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
            projects[index].lastModifiedDate = Date()
            saveProjects()
        }
    }
    
    private func saveProjects() {
        do {
            let data = try JSONEncoder().encode(projects)
            try data.write(to: saveURL, options: [.atomic, .completeFileProtection])
            print("Successfully saved \(projects.count) projects. Clip counts: \(projects.map { "\($0.title): \($0.timeline.clips.count) clips" })")
        } catch {
            print("Failed to save projects: \(error)")
        }
    }
    
    private func loadProjects() {
        guard FileManager.default.fileExists(atPath: saveURL.path) else {
            print("No saved projects file found at \(saveURL.path), starting empty")
            self.projects = []
            return
        }
        
        do {
            let data = try Data(contentsOf: saveURL)
            let decoded = try JSONDecoder().decode([VideoProject].self, from: data)
            self.projects = decoded.sorted(by: { $0.lastModifiedDate > $1.lastModifiedDate })
            print("Successfully loaded \(projects.count) projects. Clip counts: \(projects.map { "\($0.title): \($0.timeline.clips.count) clips" })")
        } catch {
            print("Failed to load projects: \(error), starting empty")
            self.projects = []
        }
    }
}
