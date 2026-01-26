import Foundation
import SwiftUI
import Combine

// MARK: - Custom Syntax Mode Definition

struct CustomSyntaxMode: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var fileExtensions: [String]
    var keywords: [String]
    var lineComment: String
    var blockCommentStart: String
    var blockCommentEnd: String
    var syntaxPatterns: [SyntaxPattern]
    
    init(
        id: UUID = UUID(),
        name: String,
        fileExtensions: [String],
        keywords: [String] = [],
        lineComment: String = "",
        blockCommentStart: String = "",
        blockCommentEnd: String = "",
        syntaxPatterns: [SyntaxPattern] = []
    ) {
        self.id = id
        self.name = name
        self.fileExtensions = fileExtensions
        self.keywords = keywords
        self.lineComment = lineComment
        self.blockCommentStart = blockCommentStart
        self.blockCommentEnd = blockCommentEnd
        self.syntaxPatterns = syntaxPatterns
    }
}

// MARK: - Syntax Pattern

struct SyntaxPattern: Codable, Hashable {
    var pattern: String
    var colorName: String  // "comment", "keyword", "string", "number", "type", "constant"
    
    init(pattern: String, colorName: String) {
        self.pattern = pattern
        self.colorName = colorName
    }
    
    func color(for colorScheme: ColorScheme = .dark) -> Color {
        let theme = ThemeManager.shared.currentTheme
        switch colorName.lowercased() {
        case "comment":
            return theme.comment.color(for: colorScheme)
        case "keyword":
            return theme.keyword.color(for: colorScheme)
        case "string":
            return theme.string.color(for: colorScheme)
        case "number":
            return theme.number.color(for: colorScheme)
        case "type":
            return theme.type.color(for: colorScheme)
        case "constant":
            return Color.purple
        default:
            return theme.foreground.color(for: colorScheme)
        }
    }
}

// MARK: - Custom Syntax Mode Manager

class CustomSyntaxModeManager: ObservableObject {
    static let shared = CustomSyntaxModeManager()
    
    @Published private(set) var customModes: [CustomSyntaxMode] = []
    
    private let storageKey = "customSyntaxModes"
    
    private init() {
        loadCustomModes()
    }
    
    // MARK: - File Detection
    
    func modeForExtension(_ ext: String) -> SyntaxMode? {
        // Custom modes are handled separately, this returns nil to indicate no built-in match
        // The actual custom mode lookup happens in the highlighting system
        return nil
    }
    
    func customModeForExtension(_ ext: String) -> CustomSyntaxMode? {
        return customModes.first { mode in
            mode.fileExtensions.contains { $0.lowercased() == ext.lowercased() }
        }
    }
    
    // MARK: - CRUD Operations
    
    func addCustomMode(_ mode: CustomSyntaxMode) {
        customModes.append(mode)
        saveCustomModes()
    }
    
    func updateCustomMode(_ mode: CustomSyntaxMode) {
        if let index = customModes.firstIndex(where: { $0.id == mode.id }) {
            customModes[index] = mode
            saveCustomModes()
        }
    }
    
    func deleteCustomMode(_ mode: CustomSyntaxMode) {
        customModes.removeAll { $0.id == mode.id }
        saveCustomModes()
    }
    
    func deleteCustomMode(id: UUID) {
        customModes.removeAll { $0.id == id }
        saveCustomModes()
    }
    
    // MARK: - Persistence
    
    private func saveCustomModes() {
        if let encoded = try? JSONEncoder().encode(customModes) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
    
    private func loadCustomModes() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([CustomSyntaxMode].self, from: data) {
            customModes = decoded
        }
    }
    
    // MARK: - Syntax Patterns for Custom Modes
    
    func syntaxPatterns(for customMode: CustomSyntaxMode, colorScheme: ColorScheme = .dark) -> [(pattern: String, color: Color)] {
        return customMode.syntaxPatterns.map { pattern in
            (pattern: pattern.pattern, color: pattern.color(for: colorScheme))
        }
    }
}

