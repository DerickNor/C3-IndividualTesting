import Foundation
import SwiftUI
import PhotosUI
import AVFoundation

extension TimelineEditorViewModel {
    
    // MARK: - Add Clips
    
    @MainActor
    func addVideoClip(from item: PhotosPickerItem?, targetTrack: Int = 0) {
        guard let item = item else { return }
        addVideoClips(from: [item], targetTrack: targetTrack)
    }
    
    @MainActor
    func addVideoClips(from items: [PhotosPickerItem], targetTrack: Int = 0) {
        guard !items.isEmpty else { return }
        
        Task {
            let targetTrackType = targetTrack
            var newClips: [Clip] = []
            for item in items {
                do {
                    if let movie = try await item.loadTransferable(type: Movie.self) {
                        let fileManager = FileManager.default
                        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        let permanentURL = documentsURL.appendingPathComponent("\(UUID().uuidString).mov")
                        
                        try fileManager.copyItem(at: movie.url, to: permanentURL)
                        
                        let asset = AVURLAsset(url: permanentURL)
                        let duration = try await asset.load(.duration)
                        let seconds = duration.seconds
                        
                        let existingMax = timeline.clips.filter { $0.trackType == targetTrackType }.map { $0.startTime + $0.duration }.max() ?? 0
                        let newMax = newClips.map { $0.startTime + $0.duration }.max() ?? 0
                        let startTime = max(existingMax, newMax)
                        
                        let newClip = Clip(
                            id: UUID(),
                            name: "Video \(timeline.clips.count + newClips.count + 1)",
                            startTime: startTime,
                            duration: seconds,
                            color: .blue,
                            trackType: targetTrackType,
                            url: permanentURL,
                            assetDuration: seconds
                        )
                        newClips.append(newClip)
                    }
                } catch {
                    print("Failed to load video: \(error.localizedDescription)")
                }
            }
            
            if !newClips.isEmpty {
                self.snapshotForUndo()
                self.timeline.clips.append(contentsOf: newClips)
                self.rippleClips(for: targetTrackType)
                Task { await self.rebuildComposition(); self.save() }
            }
        }
    }
    
    @MainActor
    func addVideoClips(fromURLs urls: [URL], targetTrack: Int = 0) {
        guard !urls.isEmpty else { return }
        
        Task {
            let targetTrackType = targetTrack
            var newClips: [Clip] = []
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                do {
                    let fileManager = FileManager.default
                    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let permanentURL = documentsURL.appendingPathComponent("\(UUID().uuidString).\(url.pathExtension)")
                    
                    try fileManager.copyItem(at: url, to: permanentURL)
                    
                    let asset = AVURLAsset(url: permanentURL)
                    let duration = try await asset.load(.duration).seconds
                    
                    let existingMax = timeline.clips.filter { $0.trackType == targetTrackType }.map { $0.startTime + $0.duration }.max() ?? 0
                    let newMax = newClips.map { $0.startTime + $0.duration }.max() ?? 0
                    let startTime = max(existingMax, newMax)
                    
                    let newClip = Clip(
                        id: UUID(),
                        name: "Video \(timeline.clips.count + newClips.count + 1)",
                        startTime: startTime,
                        duration: duration,
                        color: .blue,
                        trackType: targetTrackType,
                        url: permanentURL,
                        sourceStartTime: 0,
                        assetDuration: duration
                    )
                    newClips.append(newClip)
                } catch {
                    print("Error importing file from URL: \(error)")
                }
            }
            
            await MainActor.run {
                if !newClips.isEmpty {
                    self.snapshotForUndo()
                    self.timeline.clips.append(contentsOf: newClips)
                    self.rippleClips(for: targetTrackType)
                    Task { await self.rebuildComposition(); self.save() }
                }
            }
        }
    }
    
    @MainActor
    func addAudioClips(fromURLs urls: [URL]) {
        guard !urls.isEmpty else { return }
        
        Task {
            let targetTrackType = 2
            var newClips: [Clip] = []
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                
                do {
                    let fileManager = FileManager.default
                    let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    let permanentURL = documentsURL.appendingPathComponent("\(UUID().uuidString).\(url.pathExtension)")
                    
                    try fileManager.copyItem(at: url, to: permanentURL)
                    
                    let asset = AVURLAsset(url: permanentURL)
                    let duration = try await asset.load(.duration).seconds
                    
                    let existingMax = timeline.clips.filter { $0.trackType == targetTrackType }.map { $0.startTime + $0.duration }.max() ?? 0
                    let newMax = newClips.map { $0.startTime + $0.duration }.max() ?? 0
                    let startTime = max(existingMax, newMax)
                    
                    let newClip = Clip(
                        id: UUID(),
                        name: "Audio \(timeline.clips.count + newClips.count + 1)",
                        startTime: startTime,
                        duration: duration,
                        color: .green,
                        trackType: targetTrackType,
                        url: permanentURL,
                        sourceStartTime: 0,
                        assetDuration: duration
                    )
                    newClips.append(newClip)
                } catch {
                    print("Error importing audio from URL: \(error)")
                }
            }
            
            await MainActor.run {
                if !newClips.isEmpty {
                    self.snapshotForUndo()
                    self.timeline.clips.append(contentsOf: newClips)
                    self.rippleClips(for: targetTrackType)
                    Task { await self.rebuildComposition(); self.save() }
                }
            }
        }
    }
    
    @MainActor
    func addTextClip(text: String = "New Text") {
        let targetTrackType = 3
        let duration: TimeInterval = 3.0 // Default 3 seconds
        
        let existingMax = timeline.clips.filter { $0.trackType == targetTrackType }.map { $0.startTime + $0.duration }.max() ?? 0
        let startTime = existingMax
        
        let newClip = Clip(
            id: UUID(),
            name: text,
            startTime: startTime,
            duration: duration,
            color: .red,
            trackType: targetTrackType,
            url: nil,
            sourceStartTime: 0,
            assetDuration: duration
        )
        
        self.snapshotForUndo()
        self.timeline.clips.append(newClip)
        self.rippleClips(for: targetTrackType)
        Task { await self.rebuildComposition(); self.save() }
    }
    
    // MARK: - Ripple & Move
    
    func rippleClips(for trackType: TrackType) {
        let trackClips = timeline.clips.filter { $0.trackType == trackType }.sorted { $0.startTime < $1.startTime }
        var currentOffset: TimeInterval = 0.0
        for clip in trackClips {
            if let idx = timeline.clips.firstIndex(where: { $0.id == clip.id }) {
                timeline.clips[idx].startTime = currentOffset
                currentOffset += timeline.clips[idx].duration
            }
        }
    }
    
    func moveClip(id: UUID, toTrack: Int) {
        if let index = timeline.clips.firstIndex(where: { $0.id == id }) {
            timeline.clips[index].trackType = toTrack
        }
    }
    
    func cleanupEmptyTracks() {
        // Disabled: We now use fixed track layers (0: Main, 1: Overlay, 2: Audio, 3: Text)
        // Shifting tracks down would break this structure.
    }
    
    // MARK: - Drag & Trim
    
    @MainActor
    func handleReorderDrag(clipID: UUID, initialStartTime: TimeInterval, translation: CGFloat, pointsPerSecond: CGFloat) {
        guard let currentIndex = timeline.clips.firstIndex(where: { $0.id == clipID }) else { return }
        let draggedClip = timeline.clips[currentIndex]
        let trackType = draggedClip.trackType
        
        let initialBaseX = initialStartTime * pointsPerSecond
        let width = draggedClip.duration * pointsPerSecond
        let virtualCenterX = initialBaseX + translation + (width / 2)
        
        var trackClips = timeline.clips.filter { $0.trackType == trackType }.sorted { $0.startTime < $1.startTime }
        
        trackClips.sort { clip1, clip2 in
            let center1 = (clip1.id == clipID) ? virtualCenterX : ((clip1.startTime + (clip1.duration / 2)) * pointsPerSecond)
            let center2 = (clip2.id == clipID) ? virtualCenterX : ((clip2.startTime + (clip2.duration / 2)) * pointsPerSecond)
            return center1 < center2
        }
        
        var currentOffset: TimeInterval = 0.0
        for i in 0..<trackClips.count {
            trackClips[i].startTime = currentOffset
            currentOffset += trackClips[i].duration
        }
        
        timeline.clips.removeAll(where: { $0.trackType == trackType })
        timeline.clips.append(contentsOf: trackClips)
    }
    
    func handleCompressedReorderDrag(clipID: UUID, trackType: TrackType, virtualCenterX: CGFloat, thumbWidth: CGFloat) {
        var trackClips = timeline.clips.filter { $0.trackType == trackType }.sorted { $0.startTime < $1.startTime }
        
        let originalIndices = Dictionary(uniqueKeysWithValues: trackClips.enumerated().map { ($0.element.id, $0.offset) })
        
        trackClips.sort { clip1, clip2 in
            let c1Center = (clip1.id == clipID) ? virtualCenterX : (CGFloat(originalIndices[clip1.id]!) * thumbWidth + thumbWidth / 2)
            let c2Center = (clip2.id == clipID) ? virtualCenterX : (CGFloat(originalIndices[clip2.id]!) * thumbWidth + thumbWidth / 2)
            return c1Center < c2Center
        }
        
        var currentOffset: TimeInterval = 0.0
        for i in 0..<trackClips.count {
            trackClips[i].startTime = currentOffset
            currentOffset += trackClips[i].duration
        }
        
        timeline.clips.removeAll(where: { $0.trackType == trackType })
        timeline.clips.append(contentsOf: trackClips)
    }
    
    @MainActor
    func updateClipTrim(id: UUID, startTime: TimeInterval, duration: TimeInterval, sourceStartTime: TimeInterval, resetToStart: Bool = true) {
        if let index = timeline.clips.firstIndex(where: { $0.id == id }) {
            self.snapshotForUndo()
            let trackType = timeline.clips[index].trackType
            timeline.clips[index].startTime = max(0, startTime)
            timeline.clips[index].duration = max(0.1, duration)
            timeline.clips[index].sourceStartTime = max(0, sourceStartTime)
            
            rippleClips(for: trackType)
            
            Task {
                await self.rebuildComposition()
                self.save()
                if resetToStart {
                    self.currentTime = 0
                    self.scrub(to: 0, exact: true)
                    self.syncScroll()
                } else {
                    self.scrub(to: self.currentTime, exact: true)
                }
            }
        }
    }
    
    @MainActor
    func splitClip(at time: TimeInterval) {
        guard let selectedID = selectedClipID,
              let index = timeline.clips.firstIndex(where: { $0.id == selectedID }) else { return }
        
        let original = timeline.clips[index]
        
        guard time > original.startTime + 0.1,
              time < original.startTime + original.duration - 0.1 else { return }
        
        let leftDuration  = time - original.startTime
        let rightDuration = original.duration - leftDuration
        let gap: TimeInterval = 0
        
        let wasPlaying = self.isPlaying
        self.pause() // Pause to prevent lag during composition rebuild
        
        snapshotForUndo()
        
        var leftClip = original
        leftClip.duration = leftDuration
        
        let rightClip = Clip(
            id: UUID(),
            name: original.name + " (2)",
            startTime: original.startTime + leftDuration + gap,
            duration: rightDuration,
            color: original.color,
            trackType: original.trackType,
            url: original.url,
            sourceStartTime: original.sourceStartTime + leftDuration,
            assetDuration: original.assetDuration
        )
        
        timeline.clips.remove(at: index)
        timeline.clips.append(leftClip)
        timeline.clips.append(rightClip)
        
        rippleClips(for: original.trackType)
        selectedClipID = leftClip.id
        
        Task {
            await self.rebuildComposition()
            self.save()
            self.scrub(to: time, exact: true)
            if wasPlaying {
                self.play()
            }
        }
    }
    
    @MainActor
    func deleteClip(id: UUID) {
        if let index = timeline.clips.firstIndex(where: { $0.id == id }) {
            let wasPlaying = self.isPlaying
            self.pause() // Pause to prevent lag during composition rebuild
            
            self.snapshotForUndo()
            let trackType = timeline.clips[index].trackType
            timeline.clips.remove(at: index)
            rippleClips(for: trackType)
            self.cleanupEmptyTracks()
            
            Task {
                await self.rebuildComposition()
                self.save()
                if wasPlaying {
                    self.play()
                }
            }
        }
    }
}
