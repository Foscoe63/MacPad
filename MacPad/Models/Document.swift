import Foundation
import Combine
import Combine

class Document: Identifiable, ObservableObject {
    let id = UUID()
    
    @Published var name: String
    @Published var content: String = ""
    @Published var path: URL?
    @Published var syntaxMode: SyntaxMode
    @Published var encoding: String = "UTF-8"
    @Published var cursorPosition: Int = 0
    @Published var isModified: Bool = false
    // Transient rich text content for runtime display (not persisted)
    @Published var attributedContent: NSAttributedString?
    
    init(name: String = "Untitled", content: String = "", path: URL? = nil, syntaxMode: SyntaxMode = .swift, attributedContent: NSAttributedString? = nil) {
        self.name = name
        self.content = content
        self.path = path
        self.syntaxMode = syntaxMode
        self.attributedContent = attributedContent
        
        // Set name from file if available
        if let path = path {
            self.name = path.lastPathComponent
            // Detect syntax mode from extension
            if let detectedMode = SyntaxMode.from(path: path) {
                self.syntaxMode = detectedMode
            }
        }
    }
    
    func save() throws {
        guard let path = path else { return }
        
        try content.write(to: path, atomically: true, encoding: .utf8)
        isModified = false
    }
    
    func load() throws {
        guard let path = path, fileManager.fileExists(atPath: path.path) else { return }
        
        content = try String(contentsOf: path, encoding: .utf8)
        name = path.lastPathComponent
        isModified = false
        
        // Detect syntax mode from extension
        if let detectedMode = SyntaxMode.from(path: path) {
            syntaxMode = detectedMode
        }
    }
    
    private let fileManager = FileManager.default
}

extension SyntaxMode {
    static func from(path: URL) -> SyntaxMode? {
        let ext = path.pathExtension.lowercased()
        
        switch ext {
        case "swift":
            return .swift
        case "py", "python":
            return .python
        case "js", "jsx":
            return .javascript
        case "json":
            return .json
        case "html", "htm":
            return .html
        case "css":
            return .css
        default:
            return nil
        }
    }
}
