import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct TabStripView: View {
    @EnvironmentObject private var appState: AppState
    @AppStorage("application.textMode") private var textMode: String = "plain"
    @AppStorage("tabs.draggable") private var tabsDraggable: Bool = true
    
    @State private var draggedTab: UUID?
    @State private var dragOverIndex: Int?

    var isRichText: Bool { textMode.lowercased() == "rich" }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(appState.documents.enumerated()), id: \.element.id) { index, document in
                    TabPill(
                        document: document,
                        isSelected: appState.selectedTab == document.id,
                        isDragging: draggedTab == document.id,
                        dragOver: dragOverIndex == index,
                        onSelect: { appState.selectedTab = document.id },
                        onClose: { close(document: document) },
                        onRename: { rename(document: document) }
                    )
                    .onDrag {
                        guard tabsDraggable else { return NSItemProvider() }
                        draggedTab = document.id
                        return NSItemProvider(object: document.id.uuidString as NSString)
                    }
                    .onDrop(of: [.text], delegate: TabDropDelegate(
                        appState: appState,
                        draggedTab: $draggedTab,
                        dragOverIndex: $dragOverIndex,
                        targetIndex: index,
                        enabled: tabsDraggable
                    ))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }


    // MARK: - Close with unsaved warning
    private func close(document: Document) {
        if document.isModified {
            let alert = NSAlert()
            alert.messageText = "Do you want to save the changes made to \(document.name)?"
            alert.informativeText = "Your changes will be lost if you don’t save them."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Save")          // .alertFirstButtonReturn
            alert.addButton(withTitle: "Don’t Save")    // .alertSecondButtonReturn
            alert.addButton(withTitle: "Cancel")        // .alertThirdButtonReturn

            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                if save(document: document) {
                    appState.removeDocument(id: document.id)
                }
            case .alertSecondButtonReturn:
                appState.removeDocument(id: document.id)
            default:
                break
            }
        } else {
            appState.removeDocument(id: document.id)
        }
    }

    private func save(document: Document) -> Bool {
        if let url = document.path {
            // Determine format by extension
            let ext = url.pathExtension.lowercased()
            let type: UTType
            switch ext {
            case "rtf": type = .rtf
            case "html", "htm": type = .html
            default: type = .plainText
            }
            do {
                try writeDocument(document, to: url, as: type)
                document.isModified = false
                return true
            } catch {
                let alert = NSAlert()
                alert.messageText = "Failed to Save"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return false
            }
        } else {
            guard let result = SavePanelHelper.presentSavePanel(suggestedName: document.name, initialURL: document.path) else { return false }
            do {
                try writeDocument(document, to: result.url, as: result.type)
                document.path = result.url
                document.name = result.url.lastPathComponent
                document.isModified = false
                return true
            } catch {
                let alert = NSAlert()
                alert.messageText = "Failed to Save"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return false
            }
        }
    }

    private func focusedTextView() -> NSTextView? {
        NSApp.keyWindow?.firstResponder as? NSTextView
    }

    private func writeDocument(_ doc: Document, to url: URL, as type: UTType) throws {
        if type == .plainText {
            try doc.content.write(to: url, atomically: true, encoding: .utf8)
            return
        }
        if let tv = focusedTextView() {
            let attr = tv.attributedString()
            let full = NSRange(location: 0, length: attr.length)
            if type == .rtf {
                let data = try attr.data(from: full, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                try data.write(to: url, options: .atomic)
            } else if type == .html {
                let data = try attr.data(from: full, documentAttributes: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ])
                try data.write(to: url, options: .atomic)
            }
        } else {
            try doc.content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Rename Tab (display name only)
    private func rename(document: Document) {
        let alert = NSAlert()
        alert.messageText = "Rename Tab"
        alert.informativeText = "Enter a new name for this tab. This changes only the tab’s display name and does not rename the file on disk."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(string: document.name)
        input.frame = NSRect(x: 0, y: 0, width: 260, height: 24)
        alert.accessoryView = input

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let newName = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newName.isEmpty {
                document.name = newName
            }
        }
    }
}

private struct TabPill: View {
    @ObservedObject var document: Document
    let isSelected: Bool
    let isDragging: Bool
    let dragOver: Bool
    let onSelect: () -> Void
    let onClose: () -> Void
    let onRename: () -> Void

    @State private var hovering = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.text")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Text(document.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
            if document.isModified {
                Image(systemName: "circle.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(.orange)
                    .help("Unsaved changes")
            }
            Button(action: onClose) {
                Image(systemName: hovering ? "xmark.circle.fill" : "xmark.circle")
                    .font(.system(size: 12))
                    .foregroundStyle(hovering ? .primary : .secondary)
                    .help("Close Tab")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(
                    dragOver ? Color.accentColor.opacity(0.8) : (isSelected ? Color.accentColor.opacity(0.6) : Color.clear),
                    lineWidth: dragOver ? 2 : 1
                )
        )
        .opacity(isDragging ? 0.5 : 1.0)
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .onTapGesture { onSelect() }
        .onHover { hovering = $0 }
        .animation(.easeInOut(duration: 0.15), value: hovering)
        .animation(.easeInOut(duration: 0.15), value: isDragging)
        .animation(.easeInOut(duration: 0.15), value: dragOver)
        .contextMenu {
            Button("Rename…", action: onRename)
        }
    }
}

// MARK: - Tab Drop Delegate

struct TabDropDelegate: DropDelegate {
    let appState: AppState
    @Binding var draggedTab: UUID?
    @Binding var dragOverIndex: Int?
    let targetIndex: Int
    let enabled: Bool
    
    func performDrop(info: DropInfo) -> Bool {
        guard enabled else { return false }
        guard let itemProvider = info.itemProviders(for: [.text]).first else {
            Task { @MainActor in
                draggedTab = nil
                dragOverIndex = nil
            }
            return false
        }
        
        itemProvider.loadItem(forTypeIdentifier: "public.text", options: nil) { data, error in
            guard let data = data as? Data,
                  let uuidString = String(data: data, encoding: .utf8),
                  let draggedId = UUID(uuidString: uuidString) else {
                Task { @MainActor in
                    draggedTab = nil
                    dragOverIndex = nil
                }
                return
            }
            
            Task { @MainActor in
                guard let sourceIndex = appState.documents.firstIndex(where: { $0.id == draggedId }),
                      sourceIndex != targetIndex else {
                    draggedTab = nil
                    dragOverIndex = nil
                    return
                }
                
                var documents = appState.documents
                let item = documents.remove(at: sourceIndex)
                let adjustedDestination = sourceIndex < targetIndex ? targetIndex - 1 : targetIndex
                documents.insert(item, at: adjustedDestination)
                appState.documents = documents
                draggedTab = nil
                dragOverIndex = nil
            }
        }
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        dragOverIndex = targetIndex
    }
    
    func dropExited(info: DropInfo) {
        // Keep dragOverIndex set until drop completes or cancels
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}
