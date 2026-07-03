import Foundation
import SwiftUI

extension TimelineEditorViewModel {
    
    // MARK: - Undo & Redo
    
    func snapshotForUndo() {
        undoStack.append(timeline)
        if undoStack.count > 10 {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }
    
    @MainActor
    func undo() {
        guard let last = undoStack.popLast() else { return }
        redoStack.append(timeline)
        timeline = last
        Task { await rebuildComposition(); save() }
    }
    
    @MainActor
    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(timeline)
        timeline = next
        Task { await rebuildComposition(); save() }
    }
}
