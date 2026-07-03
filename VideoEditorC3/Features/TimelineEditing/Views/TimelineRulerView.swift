import SwiftUI

struct TimelineRulerView: View {
    let totalDuration: TimeInterval
    let pointsPerSecond: CGFloat
    
    var body: some View {
        let width = totalDuration * pointsPerSecond
        let seconds = Int(totalDuration)
        
        ZStack(alignment: .leading) {
            ForEach(Array(stride(from: 0, through: seconds, by: 2)), id: \.self) { second in
                VStack(spacing: 2) {
                    Text(formatTimeWithoutMs(TimeInterval(second)))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                    Rectangle()
                        .fill(Color.gray)
                        .frame(width: 1, height: 6)
                    Spacer()
                }
                .frame(width: 40) // Give text room to breathe
                .offset(x: CGFloat(second) * pointsPerSecond - 20)
            }
        }
        .frame(width: width, alignment: .leading)
    }
    
    private func formatTimeWithoutMs(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
