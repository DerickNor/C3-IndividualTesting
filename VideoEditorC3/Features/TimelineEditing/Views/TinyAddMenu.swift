import SwiftUI

struct TinyAddMenu: View {
    let actionPhoto: () -> Void
    let actionFiles: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: actionPhoto) {
                HStack(spacing: 6) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                    Text("Photo Album")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            
            Divider()
            
            Button(action: actionFiles) {
                HStack(spacing: 6) {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                    Text("Files")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .frame(height: 32)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(width: 130)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
        )
    }
}
