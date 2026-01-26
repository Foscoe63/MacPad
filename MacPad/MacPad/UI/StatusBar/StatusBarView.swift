import SwiftUI

struct StatusBarView: View {
    @ObservedObject var document: Document
    
    private var modificationDateString: String {
        guard let modDate = document.modificationDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: modDate)
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Cursor position (actual line/column from text view)
            Text("Ln \(document.cursorLine), Col \(document.cursorColumn)")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Divider()
                .frame(height: 12)
            
            // Syntax mode
            Text(document.syntaxMode.displayName)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // File encoding
            if !document.encoding.isEmpty {
                Text(document.encoding)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Divider()
                    .frame(height: 12)
            }
            
            // Modification date
            if !modificationDateString.isEmpty {
                Text(modificationDateString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Divider()
                    .frame(height: 12)
            }
            
            // Character count
            Text("\(document.content.count) chars")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(6)
        .background(.thinMaterial)
        .frame(height: Constants.statusBarHeight)
    }
}