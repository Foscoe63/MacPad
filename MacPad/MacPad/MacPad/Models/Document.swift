import Foundation
import Combine

class Document: Identifiable, ObservableObject {
    let id = UUID()
    
    @Published var name: String
    @Published var content: String = ""
    @Published var path: URL?
    @Published var syntaxMode: SyntaxMode
    @Published var encoding: String = "UTF-8"
    @Published var cursorPosition: Int = 0
    @Published var cursorLine: Int = 1
    @Published var cursorColumn: Int = 1
    @Published var isModified: Bool = false
    @Published var modificationDate: Date?
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
        
        // Try to detect encoding
        var detectedEncoding: String.Encoding = .utf8
        if let data = try? Data(contentsOf: path) {
            // Try common encodings in order
            if let string = String(data: data, encoding: .utf8) {
                content = string
                detectedEncoding = .utf8
            } else if let string = String(data: data, encoding: .utf16) {
                content = string
                detectedEncoding = .utf16
            } else if let string = String(data: data, encoding: .macOSRoman) {
                content = string
                detectedEncoding = .macOSRoman
            } else if let string = String(data: data, encoding: .isoLatin1) {
                content = string
                detectedEncoding = .isoLatin1
            } else {
                // Fallback to UTF-8
                content = try String(contentsOf: path, encoding: .utf8)
                detectedEncoding = .utf8
            }
        } else {
            content = try String(contentsOf: path, encoding: .utf8)
        }
        
        // Set encoding string
        switch detectedEncoding {
        case .utf8: encoding = "UTF-8"
        case .utf16: encoding = "UTF-16"
        case .macOSRoman: encoding = "MacRoman"
        case .ascii: encoding = "ASCII"
        case .isoLatin1: encoding = "ISO-8859-1"
        case .windowsCP1252: encoding = "Windows-1252"
        default: encoding = "UTF-8"
        }
        
        name = path.lastPathComponent
        isModified = false
        
        // Get modification date
        if let attributes = try? fileManager.attributesOfItem(atPath: path.path),
           let modDate = attributes[.modificationDate] as? Date {
            modificationDate = modDate
        }
        
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
        
        // Check for custom syntax modes first
        if CustomSyntaxModeManager.shared.customModeForExtension(ext) != nil {
            // Custom mode exists - return nil so Document defaults to .swift
            // The actual highlighting will use the custom mode patterns via fileExtension
            return nil
        }
        
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
        case "ts", "tsx":
            return .typescript
        case "md", "markdown", "mdown", "mkd":
            return .markdown
        case "yaml", "yml":
            return .yaml
        case "xml", "xsd", "xsl", "xslt":
            return .xml
        case "sh", "bash", "zsh", "fish", "csh", "ksh":
            return .shell
        default:
            // No built-in mode matched
            return nil
        }
    }
}
