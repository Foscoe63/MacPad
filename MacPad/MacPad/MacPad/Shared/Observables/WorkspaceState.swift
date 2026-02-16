import Foundation
import Combine
import AppKit
import UniformTypeIdentifiers

class WorkspaceState: ObservableObject {
    @Published var workspaceRoot: URL?
    @Published var expandedFolders: Set<String> = []
    @Published var volumes: [URL] = []
    
    private let bookmarkKey = "workspaceBookmark"
    private var accessedURL: URL?
    
    init() {
        refreshVolumes()
        // Always default to Documents directory on app launch
        if let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            setWorkspaceRoot(to: documents, persist: false)
        } else {
            // Fallback to home directory if Documents cannot be resolved
            let home = FileManager.default.homeDirectoryForCurrentUser
            setWorkspaceRoot(to: home, persist: false)
        }
    }
    
    // MARK: - Volumes
    func refreshVolumes() {
        let keys: [URLResourceKey] = [
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeIsLocalKey,
            .volumeNameKey
        ]
        let urls = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: keys, options: []) ?? []

        // Read user preferences (defaults applied if unset)
        let defaults = UserDefaults.standard
        let showInternal = defaults.object(forKey: "volumes.showInternal") as? Bool ?? true
        let showExternal = defaults.object(forKey: "volumes.showExternal") as? Bool ?? true
        let showNetwork  = defaults.object(forKey: "volumes.showNetwork")  as? Bool ?? false
        let hideSystem   = defaults.object(forKey: "volumes.hideSystem")   as? Bool ?? true
        let hideBackups  = defaults.object(forKey: "volumes.hideBackups")  as? Bool ?? true

        // System/hidden names to filter when requested
        let systemNames: Set<String> = ["preboot","vm","update","raid","iscpreboot","hardware","recovery","xart"]
        // Backup/snapshot indicators (case-insensitive); check both volume name and full path
        let backupNamePatterns: [String] = [
            "snapshot",
            "time machine",
            "timemachine",
            "time machine backups",
            "backups.backupdb",
            "mobilebackups",
            "com.apple.timemachine"
        ]

        let filtered = urls.filter { url in
            let vals = try? url.resourceValues(forKeys: Set(keys))
            let isLocal = vals?.volumeIsLocal ?? true
            let isRemovable = vals?.volumeIsRemovable ?? false
            let isEjectable = vals?.volumeIsEjectable ?? false
            let name = (vals?.volumeName ?? url.lastPathComponent).lowercased()
            let pathLower = url.path.lowercased()
            let components = Set(url.pathComponents.map { $0.lowercased() })

            let isExternal = (!isLocal) || isRemovable || isEjectable
            let isNetwork = (!isLocal) && !isRemovable && !isEjectable

            // Category filters
            if isNetwork && !showNetwork { return false }
            if !isExternal && !showInternal { return false }
            if isExternal && !isNetwork && !showExternal { return false }

            // System/backups filters
            if hideSystem {
                if systemNames.contains(name) { return false }
            }
            if hideBackups {
                // Match known Time Machine and backup snapshot locations by name and path
                let nameMatches = backupNamePatterns.contains { pat in name.contains(pat) }
                let pathMatches = backupNamePatterns.contains { pat in pathLower.contains(pat) }
                let componentMatches = components.contains(".mobilebackups") || components.contains("mobilebackups") || components.contains("backups.backupdb") || components.contains("timemachine")
                if nameMatches || pathMatches || componentMatches {
                    return false
                }
            }
            return true
        }

        // Keep predictable order: internal first, then external/removable/network; then by name
        self.volumes = filtered.sorted { lhs, rhs in
            let lvals = try? lhs.resourceValues(forKeys: Set(keys))
            let rvals = try? rhs.resourceValues(forKeys: Set(keys))
            let lIsLocal = lvals?.volumeIsLocal ?? true
            let rIsLocal = rvals?.volumeIsLocal ?? true
            let lIsRem = lvals?.volumeIsRemovable ?? false
            let rIsRem = rvals?.volumeIsRemovable ?? false
            let lIsEj = lvals?.volumeIsEjectable ?? false
            let rIsEj = rvals?.volumeIsEjectable ?? false
            let lExternal = (!lIsLocal) || lIsRem || lIsEj
            let rExternal = (!rIsLocal) || rIsRem || rIsEj
            if lExternal != rExternal { return !lExternal && rExternal } // internal first
            let lname = lvals?.volumeName ?? lhs.lastPathComponent
            let rname = rvals?.volumeName ?? rhs.lastPathComponent
            return lname.localizedCaseInsensitiveCompare(rname) == .orderedAscending
        }
    }
    
    // MARK: - Folder access & bookmarks
    func pickWorkspaceRoot(startingAt url: URL? = nil) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = url ?? workspaceRoot
        panel.prompt = "Choose"
        panel.message = "Choose a folder to browse"
        if panel.runModal() == .OK, let chosen = panel.url {
            setWorkspaceRoot(to: chosen, persist: true)
        }
    }
    
    func setWorkspaceRoot(to url: URL, persist: Bool) {
        // Normalize the URL to avoid alias confusion. Do NOT resolve symlinks blindly,
        // especially for network/file provider volumes that live under user home.
        let normalized = url.standardizedFileURL
        // Prefer the remount URL for volumes when available (helps with network shares)
        let remountURL: URL? = try? normalized.resourceValues(forKeys: [.volumeURLForRemountingKey]).volumeURLForRemounting
        let finalURL = remountURL ?? normalized
        // Stop previous access if any
        if let old = accessedURL { old.stopAccessingSecurityScopedResource() }
        // Start access (works both sandboxed and non-sandboxed; non-sandboxed returns false harmlessly)
        _ = finalURL.startAccessingSecurityScopedResource()
        accessedURL = finalURL
        workspaceRoot = finalURL
        expandedFolders.insert(finalURL.path)
        if persist { saveBookmark(for: finalURL) }
    }
    
    private func saveBookmark(for url: URL) {
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        } catch {
            // Ignore bookmark save errors
        }
    }
    
    private func restoreBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                // Refresh the bookmark
                saveBookmark(for: url)
            }
            _ = url.startAccessingSecurityScopedResource()
            accessedURL = url
            return url
        } catch {
            return nil
        }
    }
    
    // MARK: - UI helpers
    func toggleFolder(_ path: String) {
        if expandedFolders.contains(path) {
            expandedFolders.remove(path)
        } else {
            expandedFolders.insert(path)
        }
    }
    
    // MARK: - File type icons
    /// Returns the system file icon for a given URL with enhanced type detection for colorful, meaningful icons.
    func iconForItem(at url: URL) -> NSImage {
        // If it's a directory, return the system folder icon for that path (keeps custom folder colors)
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
            let img = NSWorkspace.shared.icon(forFile: url.path)
            // Ensure it's not a template so colors show
            img.isTemplate = false
            return img
        }

        // For files, always try to get the actual file icon first (most accurate and colorful)
        // NSWorkspace.shared.icon(forFile:) returns colorful icons by default
        if FileManager.default.fileExists(atPath: url.path) {
            let img = NSWorkspace.shared.icon(forFile: url.path)
            // Ensure it's not a template so colors show
            img.isTemplate = false
            return img
        }

        // If file doesn't exist yet, use extension-based detection
        let rawExt = url.pathExtension.lowercased()

        if #available(macOS 12.0, *) {
            // Try to get type from file content if available (most accurate)
            if let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]),
               let contentType = resourceValues.contentType {
                let img = NSWorkspace.shared.icon(for: contentType)
                img.isTemplate = false
                return img
            }
            
            // Try UTType from extension (system provides colorful icons automatically)
            if !rawExt.isEmpty, let type = UTType(filenameExtension: rawExt) {
                let img = NSWorkspace.shared.icon(for: type)
                img.isTemplate = false
                return img
            }
            
            // Fallback to generic data type
            let img = NSWorkspace.shared.icon(for: .data)
            img.isTemplate = false
            return img
        } else {
            // Fallback for older macOS
            if !rawExt.isEmpty {
                let img = NSWorkspace.shared.icon(forFileType: rawExt)
                img.isTemplate = false
                return img
            }
            let img = NSWorkspace.shared.icon(forFileType: "public.data")
            img.isTemplate = false
            return img
        }
    }

    /// Convenience to return a SwiftUI Image for use in list rows.
    /// Usage in SwiftUI: `Image(nsImage: state.iconForItem(at: url))`
    func imageForItem(at url: URL) -> NSImage { iconForItem(at: url) }
}
