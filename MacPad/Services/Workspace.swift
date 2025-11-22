import Foundation
import Combine

class Workspace: ObservableObject {
    @Published var files: [FileItem] = []
    @Published var rootPath: URL?
    @Published var isScanning = false
    @Published var dirtyFiles: Set<URL> = []
    
    private let fileManager = FileManager.default
    private var watchers: [URL] = []
    
    init() {
        // Default to user's home directory
        rootPath = fileManager.homeDirectoryForCurrentUser
        loadWorkspace()
    }
    
    func loadWorkspace() {
        guard let root = rootPath, fileManager.fileExists(atPath: root.path) else { return }
        
        isScanning = true
        files.removeAll()
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [])
            for item in contents {
                let isDir = try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory
                let name = item.lastPathComponent
                
                files.append(FileItem(url: item, name: name, isDirectory: isDir ?? false))
            }
            
            files.sort { $0.name < $1.name }
        } catch {
            print("Error scanning workspace: \(error)")
        }
        
        isScanning = false
    }
    
    func refreshFile(_ file: FileItem) {
        guard let url = file.url else { return }
        
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            if let modifiedDate = attributes[.modificationDate] as? Date {
                if let idx = files.firstIndex(where: { $0.id == file.id }) {
                    files[idx].lastModified = modifiedDate
                }
            }
        } catch {
            print("Error refreshing \(file.name): \(error)")
        }
    }
    
    func markDirty(_ file: URL) {
        dirtyFiles.insert(file)
    }
    
    func markClean(_ file: URL) {
        dirtyFiles.remove(file)
    }
    
    func isDirty(_ file: URL) -> Bool {
        dirtyFiles.contains(file)
    }
    
    func addFile(_ url: URL) {
        let item = FileItem(url: url, name: url.lastPathComponent, isDirectory: false)
        files.append(item)
        files.sort { $0.name < $1.name }
    }
    
    func removeFile(_ url: URL) {
        files.removeAll { $0.url?.path == url.path }
    }
    
    func scanDirectory(_ path: URL) {
        guard fileManager.fileExists(atPath: path.path), !files.contains(where: { $0.url?.path == path.path }) else { return }
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: path, includingPropertiesForKeys: [.isDirectoryKey], options: [])
            for item in contents {
                let isDir = try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory
                let name = item.lastPathComponent
                
                if isDir == true {
                    files.append(FileItem(url: item, name: name, isDirectory: true))
                } else {
                    files.append(FileItem(url: item, name: name, isDirectory: false))
                }
            }
            
            files.sort { $0.name < $1.name }
        } catch {
            print("Error scanning directory: \(error)")
        }
    }
}

struct FileItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL?
    let name: String
    let isDirectory: Bool
    var lastModified: Date? = nil
    
    static func == (lhs: FileItem, rhs: FileItem) -> Bool {
        lhs.id == rhs.id
    }
}