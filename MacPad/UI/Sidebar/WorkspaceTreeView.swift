import SwiftUI
import AppKit

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

struct WorkspaceTreeView: View {
    @EnvironmentObject var workspace: WorkspaceState
    @AppStorage("browser.fontDesign") private var browserFontDesign: String = "system"
    @AppStorage("browser.fontSize") private var browserFontSize: Double = 13
    private var browserFont: Font {
        let size = CGFloat(browserFontSize)
        return browserFontDesign == "monospaced" ? .system(size: size, design: .monospaced) : .system(size: size)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if let root = workspace.workspaceRoot {
                    WorkspaceFileNodeView(path: root, isExpanded: workspace.expandedFolders.contains(root.path)) {
                        workspace.toggleFolder(root.path)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
    }
}

struct WorkspaceFileNodeView: View {
    @EnvironmentObject var workspace: WorkspaceState
    let path: URL
    let isExpanded: Bool
    let onToggle: () -> Void
    @AppStorage("browser.fontDesign") private var browserFontDesign: String = "system"
    @AppStorage("browser.fontSize") private var browserFontSize: Double = 13
    private var browserFont: Font {
        let size = CGFloat(browserFontSize)
        return browserFontDesign == "monospaced" ? .system(size: size, design: .monospaced) : .system(size: size)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: onToggle) {
                    ColorfulIconView(image: workspace.iconForItem(at: path), size: 14)
                }
                .buttonStyle(.plain)
                .tint(nil)
                
                Text(path.lastPathComponent)
                    .font(browserFont)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            if isExpanded {
                WorkspaceListContent(path: path)
                    .padding(.leading, 16)
            }
        }
    }
}


struct WorkspaceListContent: View {
    @EnvironmentObject var workspace: WorkspaceState
    let path: URL
    @AppStorage("browser.fontDesign") private var browserFontDesign: String = "system"
    @AppStorage("browser.fontSize") private var browserFontSize: Double = 13
    private var browserFont: Font {
        let size = CGFloat(browserFontSize)
        return browserFontDesign == "monospaced" ? .system(size: size, design: .monospaced) : .system(size: size)
    }
    
    var body: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            if let contents = try? FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: [.isDirectoryKey], options: []) {
                ForEach(contents.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }, id: \.path) { item in
                    if let isDir = try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory {
                        if isDir {
                            WorkspaceFileNodeView(path: item, isExpanded: false) {}
                        } else {
                            HStack(spacing: 8) {
                                ColorfulIconView(image: workspace.iconForItem(at: item), size: 14)
                                Text(item.lastPathComponent)
                                    .font(browserFont)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }
}
