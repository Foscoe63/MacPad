import SwiftUI

struct DraggableToolbarItem: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    @State private var isDragging = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.caption)
            }
            .padding(8)
            .background(
                isDragging ? Color.blue.opacity(0.2) : Color.clear
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .gesture(
            DragGesture()
                .onChanged { _ in isDragging = true }
                .onEnded { _ in isDragging = false }
        )
    }
}