import SwiftUI
import AppKit

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
        let result = image.copy() as? NSImage ?? image
        result.isTemplate = false
        nsView.image = result
        nsView.contentTintColor = nil
        if #available(macOS 13.0, *) {
            nsView.symbolConfiguration = nil
        }
    }
}

struct QuickOpenView: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var workspaceState: WorkspaceState
    @EnvironmentObject var appState: AppState
    @State private var searchText = ""
    @State private var filteredFiles: [FileItem] = []
    @State private var selectedIndex = 0
    @FocusState private var isSearchFieldFocused: Bool
    
    struct FileItem: Identifiable {
        let id = UUID()
        let url: URL
        let displayName: String
        let path: String
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search files...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isSearchFieldFocused)
                    .onChange(of: searchText) { _, _ in
                        performSearch()
                    }
                    .onSubmit {
                        openSelectedFile()
                    }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.top, 16)
            
            // Results list
            if filteredFiles.isEmpty && !searchText.isEmpty {
                VStack {
                    Spacer()
                    Text("No files found")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredFiles.isEmpty {
                VStack {
                    Spacer()
                    Text("Type to search files in workspace")
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(filteredFiles.enumerated()), id: \.element.id) { index, file in
                                HStack(spacing: 12) {
                                    ColorfulIconView(image: workspaceState.iconForItem(at: file.url), size: 16)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(file.displayName)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.primary)
                                        
                                        Text(file.path)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .contentShape(Rectangle())
                                .background(selectedIndex == index ? Color.accentColor.opacity(0.2) : Color.clear)
                                .onTapGesture {
                                    selectedIndex = index
                                    openSelectedFile()
                                }
                                .id(index)
                            }
                        }
                    }
                    .onChange(of: selectedIndex) { _, newValue in
                        withAnimation(.easeInOut(duration: 0.1)) {
                            proxy.scrollTo(newValue, anchor: .center)
                        }
                    }
                }
            }
        }
        .frame(width: 600, height: 400)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            isSearchFieldFocused = true
            performSearch()
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < filteredFiles.count - 1 {
                selectedIndex += 1
            }
            return .handled
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
            return .handled
        }
    }
    
    private func performSearch() {
        guard let workspaceRoot = workspaceState.workspaceRoot else {
            filteredFiles = []
            return
        }
        
        if searchText.isEmpty {
            // Show recent files or all files
            filteredFiles = getAllFiles(in: workspaceRoot).prefix(50).map { url in
                FileItem(url: url, displayName: url.lastPathComponent, path: getRelativePath(url, from: workspaceRoot))
            }
        } else {
            // Fuzzy search
            let allFiles = getAllFiles(in: workspaceRoot)
            let query = searchText.lowercased()
            
            filteredFiles = allFiles
                .compactMap { url -> (url: URL, score: Int)? in
                    let name = url.lastPathComponent.lowercased()
                    let path = getRelativePath(url, from: workspaceRoot).lowercased()
                    
                    // Calculate fuzzy match score
                    let nameScore = fuzzyMatch(query: query, target: name)
                    let pathScore = fuzzyMatch(query: query, target: path)
                    
                    let score = max(nameScore, pathScore)
                    return score > 0 ? (url, score) : nil
                }
                .sorted { $0.score > $1.score }
                .prefix(50)
                .map { result in
                    FileItem(url: result.url, displayName: result.url.lastPathComponent, path: getRelativePath(result.url, from: workspaceRoot))
                }
        }
        
        selectedIndex = 0
    }
    
    private func getAllFiles(in directory: URL) -> [URL] {
        var files: [URL] = []
        let fileManager = FileManager.default
        let showHidden = UserDefaults.standard.bool(forKey: "browser.showHidden")
        
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: showHidden ? [] : [.skipsHiddenFiles]
        ) else {
            return files
        }
        
        for case let fileURL as URL in enumerator {
            if let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
               resourceValues.isRegularFile == true {
                files.append(fileURL)
            }
        }
        
        return files
    }
    
    private func getRelativePath(_ url: URL, from base: URL) -> String {
        let basePath = base.path
        let filePath = url.path
        
        if filePath.hasPrefix(basePath) {
            let relative = String(filePath.dropFirst(basePath.count))
            return relative.hasPrefix("/") ? String(relative.dropFirst()) : relative
        }
        
        return url.lastPathComponent
    }
    
    private func fuzzyMatch(query: String, target: String) -> Int {
        guard !query.isEmpty && !target.isEmpty else { return 0 }
        
        var queryIndex = query.startIndex
        var targetIndex = target.startIndex
        var consecutiveMatches = 0
        var maxConsecutive = 0
        var totalMatches = 0
        
        while queryIndex < query.endIndex && targetIndex < target.endIndex {
            if query[queryIndex] == target[targetIndex] {
                consecutiveMatches += 1
                maxConsecutive = max(maxConsecutive, consecutiveMatches)
                totalMatches += 1
                queryIndex = query.index(after: queryIndex)
            } else {
                consecutiveMatches = 0
            }
            targetIndex = target.index(after: targetIndex)
        }
        
        // Bonus for complete match
        if queryIndex == query.endIndex {
            return totalMatches * 10 + maxConsecutive * 5
        }
        
        return 0
    }
    
    private func openSelectedFile() {
        guard selectedIndex >= 0 && selectedIndex < filteredFiles.count else { return }
        let file = filteredFiles[selectedIndex]
        appState.open(urls: [file.url])
        isPresented = false
    }
}

