import SwiftUI          // Provides View, @EnvironmentObject, and related UI types
import Foundation       // Brings in URL and URLResourceKey
import AppKit           // Needed for NSWorkspace (icon handling)

// MARK: - Ensure NSImage renders in full color (avoid SwiftUI templating)
private struct ColorfulIconView: NSViewRepresentable {
    let image: NSImage
    let size: CGFloat

    func makeNSView(context: Context) -> NSImageView {
        let v = NSImageView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.imageScaling = .scaleProportionallyDown
        v.imageAlignment = .alignCenter
        NSLayoutConstraint.activate([
            v.widthAnchor.constraint(equalToConstant: size),
            v.heightAnchor.constraint(equalToConstant: size)
        ])
        return v
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        // Rasterize into a fresh NSImage to strip any template/tint semantics
        let rendered = rasterize(image)
        rendered.isTemplate = false
        nsView.image = rendered
        nsView.contentTintColor = nil
        if #available(macOS 13.0, *) {
            nsView.symbolConfiguration = nil
        }
    }

    private func rasterize(_ source: NSImage) -> NSImage {
        // Simple approach: just ensure isTemplate is false and return the original
        // Avoid complex rasterization that might trigger Metal shader issues
        let result = source.copy() as? NSImage ?? source
        result.isTemplate = false
        return result
    }
}

struct FileNodeView: View {
    @EnvironmentObject var workspace: MacPad.WorkspaceState
    @EnvironmentObject var appState:   MacPad.AppState
    let path: URL
    @AppStorage("browser.fontDesign") private var browserFontDesign: String = "system"
    @AppStorage("browser.fontSize") private var browserFontSize: Double = 13
    private var browserFont: Font {
        let size = CGFloat(browserFontSize)
        return browserFontDesign == "monospaced" ? .system(size: size, design: .monospaced) : .system(size: size)
    }
    
    var isExpanded: Bool { workspace.expandedFolders.contains(path.path) }
    
    // Helper that builds the correctly‑coloured folder icon using system default colorful icons
    private var folderIcon: some View {
        let img = workspace.iconForItem(at: path)
        return ColorfulIconView(image: img, size: 14)
    }
    
    // Helper that builds the correctly‑coloured file icon using system default colorful icons
    private var fileIcon: some View {
        let img = workspace.iconForItem(at: path)
        return ColorfulIconView(image: img, size: 14)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if isDirectory(path) {
                    // Folder toggle chevron (no Button to avoid any tint)
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                        .contentShape(Rectangle())
                        .onTapGesture { workspace.toggleFolder(path.path) }
                    
                    // Folder icon – native colour retained via `folderIcon`
                    folderIcon
                    
                    Text(path.lastPathComponent)
                        .font(browserFont)
                        .foregroundStyle(.primary)
                        .textSelection(.disabled)
                        .contentShape(Rectangle())
                        .onTapGesture { workspace.toggleFolder(path.path) }
                } else {
                    // Align with folder rows
                    Spacer().frame(width: 14)
                    
                    // File icon – native colour retained via `fileIcon`
                    fileIcon
                    
                    // File name (no Button)
                    Text(path.lastPathComponent)
                        .font(browserFont)
                        .foregroundStyle(.secondary)
                        .textSelection(.disabled)
                        .contentShape(Rectangle())
                        .onTapGesture { openFile(path) }
                }
                
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                if isDirectory(path) {
                    workspace.toggleFolder(path.path)
                } else {
                    openFile(path)
                }
            }
            
            // Show children when the folder is expanded
            if isExpanded {
                SidebarListContent(path: path)
                    .padding(.leading, 16)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
    }
    
    private func openFile(_ url: URL) {
        guard !isDirectory(url) else { return }
        appState.open(urls: [url])
    }
}

// ---------------------------------------------------------------------------
// MARK: - SidebarListContent (children of a folder)
// This view was previously defined in `FileBrowserView.swift`.  It is duplicated
// here so that `FileNodeView` can compile without needing another file.
// ---------------------------------------------------------------------------

private struct SidebarListContent: View {
    @EnvironmentObject var workspace: MacPad.WorkspaceState
    @EnvironmentObject var appState:   MacPad.AppState
    
    @AppStorage("browser.showHidden") private var showHiddenFiles: Bool = false
    @AppStorage("browser.sortOrder") private var sortOrder: String = "name"
    
    let path: URL
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 2) {
            let options: FileManager.DirectoryEnumerationOptions = showHiddenFiles ? [] : [.skipsHiddenFiles]
            
            // Request additional keys based on sort order(s)
            let keys: [URLResourceKey] = {
                var result: [URLResourceKey] = [.isDirectoryKey]
                let orders = sortOrder.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }
                if orders.contains("date") {
                    result.append(.contentModificationDateKey)
                }
                if orders.contains("size") {
                    result.append(.fileSizeKey)
                }
                if orders.contains("type") {
                    result.append(.contentTypeKey)
                }
                return result
            }()
            
            if let contents = try? FileManager.default.contentsOfDirectory(at: path,
                                                                          includingPropertiesForKeys: keys,
                                                                          options: options) {
                if contents.isEmpty {
                    // Empty folder placeholder
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No items")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                } else {
                    // Sort based on preference
                    let sorted = sortFiles(contents, order: sortOrder)
                    
                    ForEach(sorted, id: \.path) { item in
                        FileNodeView(path: item)
                    }
                }
            } else {
                // Permission / access error UI
                VStack(alignment: .leading, spacing: 6) {
                    Text("Cannot read ‘\(path.lastPathComponent)’")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    
                    Button(action: { workspace.pickWorkspaceRoot(startingAt: path) }) {
                        Label("Grant Access...", systemImage: "lock.open")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.link)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    // MARK: - Sorting Helper
    
    private func sortFiles(_ files: [URL], order: String) -> [URL] {
        // Parse comma-separated sort orders
        let orders = order.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }.filter { !$0.isEmpty }
        let sortOrders = orders.isEmpty ? ["name"] : orders
        
        return files.sorted { lhs, rhs in
            let lhsIsDir = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            let rhsIsDir = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            
            // Always put directories first
            if lhsIsDir != rhsIsDir {
                return lhsIsDir
            }
            
            // Apply each sort criterion in order until we find a difference
            for sortOrder in sortOrders {
                let comparison = compareFiles(lhs, rhs, by: sortOrder, isDirectory: lhsIsDir)
                if comparison != .orderedSame {
                    return comparison == .orderedAscending
                }
            }
            
            // If all criteria are equal, use name as final tiebreaker
            return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent) == .orderedAscending
        }
    }
    
    private func compareFiles(_ lhs: URL, _ rhs: URL, by order: String, isDirectory: Bool) -> ComparisonResult {
        switch order {
        case "type":
            let lhsExt = lhs.pathExtension.lowercased()
            let rhsExt = rhs.pathExtension.lowercased()
            return lhsExt.compare(rhsExt)
            
        case "date":
            let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
            // Newest first (reverse order)
            return rhsDate.compare(lhsDate)
            
        case "size":
            // For directories, use 0 as size and compare by name
            if isDirectory {
                return .orderedSame
            }
            let lhsSize = (try? lhs.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            let rhsSize = (try? rhs.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            // Largest first (reverse order)
            if lhsSize > rhsSize {
                return .orderedAscending
            } else if lhsSize < rhsSize {
                return .orderedDescending
            } else {
                return .orderedSame
            }
            
        case "name":
            fallthrough
        default:
            return lhs.lastPathComponent.localizedCaseInsensitiveCompare(rhs.lastPathComponent)
        }
    }
}
