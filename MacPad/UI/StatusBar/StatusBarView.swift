import SwiftUI

struct StatusBarView: View {
    @ObservedObject var document: Document
    
    var body: some View {
        HStack(spacing: 12) {
            Text("Line \(document.content.components(separatedBy: .newlines).count), Col \(max(document.cursorPosition, 1))")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(document.encoding)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text("\(document.content.count) chars")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(6)
        .background(.thinMaterial)
        .frame(height: Constants.statusBarHeight)
    }
}