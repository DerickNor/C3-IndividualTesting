import SwiftUI

struct TooltipMenuItem: Identifiable {
    let id: String
    let icon: String
    let title: String
}

struct EditorTooltipMenu: View {
    let items: [TooltipMenuItem]
    let arrowOffset: CGFloat
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                TooltipButton(icon: item.icon, title: item.title) {
                    onSelect(item.id)
                }
                
                if index < items.count - 1 {
                    Divider()
                }
            }
        }
        .frame(width: 200)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        // Tail pointing down
        .background(
            VStack {
                Spacer()
                HStack {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(.systemGray4))
                        .offset(x: arrowOffset, y: 10)
                    Spacer()
                }
            }
        )
        .shadow(color: .black.opacity(0.15), radius: 10, y: 5)
    }
}

// Reusing TooltipButton
struct TooltipButton: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
