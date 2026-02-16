import SwiftUI

struct EditorView: View {
    @ObservedObject var document: Document
    
    var body: some View {
        TextView(document: document)
            .id(document.id) // Ensure a fresh NSViewRepresentable per document/tab to avoid coordinator state bleed
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
