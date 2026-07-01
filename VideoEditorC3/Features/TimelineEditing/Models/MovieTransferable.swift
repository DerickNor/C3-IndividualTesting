import Foundation
import SwiftUI
import PhotosUI
import AVFoundation

struct Movie: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            // Create a unique destination URL in the temporary directory
            let copy = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(received.file.pathExtension)
            
            // Copy the file so it persists
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Movie(url: copy)
        }
    }
}
