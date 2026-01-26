//
//  Autocomplete.swift
//  Autocomplete
//

import Foundation
import Combine

public enum SyntaxMode: String, CaseIterable {
    case swift = "swift"
    case javascript = "javascript"
    case python = "python"
    case json = "json"
    case html = "html"
    case css = "css"
    case typescript = "typescript"
    case plaintext = "plaintext"
}

public struct CompletionItem {
    public let text: String
    public let displayText: String
    public let description: String
    public let kind: CompletionKind
    
    public init(text: String, displayText: String? = nil, description: String = "", kind: CompletionKind = .text) {
        self.text = text
        self.displayText = displayText ?? text
        self.description = description
        self.kind = kind
    }
}

public enum CompletionKind {
    case method
    case function
    case variable
    case keyword
    case text
}

// Public API for the autocomplete engine
public class AutocompleteEnginePublic {
    public init() {}
    
    public func getSuggestions(for input: String, language: String, context: [String] = []) -> [CompletionItem] {
        var suggestions: [CompletionItem] = []
        
        // Get language-specific completions
        suggestions.append(contentsOf: getLanguageSpecificSuggestions(input: input, language: language))
        
        // Get context-based completions
        suggestions.append(contentsOf: getContextSuggestions(input: input, context: context))
        
        // Filter based on input
        return suggestions.filter { item in
            item.text.lowercased().hasPrefix(input.lowercased()) || 
            item.displayText.lowercased().hasPrefix(input.lowercased())
        }.sorted { $0.text < $1.text }
    }
    
    private func getLanguageSpecificSuggestions(input: String, language: String) -> [CompletionItem] {
        switch language.lowercased() {
        case "swift":
            return getSwiftCompletions()
        case "javascript", "js":
            return getJavaScriptCompletions()
        case "python", "py":
            return getPythonCompletions()
        default:
            return getDefaultCompletions()
        }
    }
    
    private func getSwiftCompletions() -> [CompletionItem] {
        return [
            CompletionItem(text: "class", kind: .keyword),
            CompletionItem(text: "struct", kind: .keyword),
            CompletionItem(text: "enum", kind: .keyword),
            CompletionItem(text: "func", kind: .keyword),
            CompletionItem(text: "var", kind: .keyword),
            CompletionItem(text: "let", kind: .keyword),
            CompletionItem(text: "if", kind: .keyword),
            CompletionItem(text: "else", kind: .keyword),
            CompletionItem(text: "for", kind: .keyword),
            CompletionItem(text: "while", kind: .keyword),
            CompletionItem(text: "import", kind: .keyword),
            CompletionItem(text: "return", kind: .keyword),
            CompletionItem(text: "init", kind: .keyword),
            CompletionItem(text: "self", kind: .variable),
            CompletionItem(text: "static", kind: .keyword),
            CompletionItem(text: "private", kind: .keyword),
            CompletionItem(text: "public", kind: .keyword),
            CompletionItem(text: "internal", kind: .keyword),
            CompletionItem(text: "print", kind: .function),
            CompletionItem(text: "Array", kind: .text),
            CompletionItem(text: "Dictionary", kind: .text),
            CompletionItem(text: "String", kind: .text),
            CompletionItem(text: "Int", kind: .text),
            CompletionItem(text: "Bool", kind: .text),
        ]
    }
    
    private func getJavaScriptCompletions() -> [CompletionItem] {
        return [
            CompletionItem(text: "function", kind: .keyword),
            CompletionItem(text: "var", kind: .keyword),
            CompletionItem(text: "let", kind: .keyword),
            CompletionItem(text: "const", kind: .keyword),
            CompletionItem(text: "if", kind: .keyword),
            CompletionItem(text: "else", kind: .keyword),
            CompletionItem(text: "for", kind: .keyword),
            CompletionItem(text: "while", kind: .keyword),
            CompletionItem(text: "import", kind: .keyword),
            CompletionItem(text: "export", kind: .keyword),
            CompletionItem(text: "return", kind: .keyword),
            CompletionItem(text: "class", kind: .keyword),
            CompletionItem(text: "this", kind: .variable),
            CompletionItem(text: "new", kind: .keyword),
            CompletionItem(text: "console.log", kind: .function),
            CompletionItem(text: "Array", kind: .text),
            CompletionItem(text: "Object", kind: .text),
            CompletionItem(text: "String", kind: .text),
            CompletionItem(text: "Number", kind: .text),
            CompletionItem(text: "Boolean", kind: .text),
        ]
    }
    
    private func getPythonCompletions() -> [CompletionItem] {
        return [
            CompletionItem(text: "def", kind: .keyword),
            CompletionItem(text: "class", kind: .keyword),
            CompletionItem(text: "if", kind: .keyword),
            CompletionItem(text: "else", kind: .keyword),
            CompletionItem(text: "elif", kind: .keyword),
            CompletionItem(text: "for", kind: .keyword),
            CompletionItem(text: "while", kind: .keyword),
            CompletionItem(text: "import", kind: .keyword),
            CompletionItem(text: "from", kind: .keyword),
            CompletionItem(text: "return", kind: .keyword),
            CompletionItem(text: "try", kind: .keyword),
            CompletionItem(text: "except", kind: .keyword),
            CompletionItem(text: "with", kind: .keyword),
            CompletionItem(text: "as", kind: .keyword),
            CompletionItem(text: "lambda", kind: .keyword),
            CompletionItem(text: "print", kind: .function),
            CompletionItem(text: "list", kind: .text),
            CompletionItem(text: "dict", kind: .text),
            CompletionItem(text: "str", kind: .text),
            CompletionItem(text: "int", kind: .text),
            CompletionItem(text: "bool", kind: .text),
        ]
    }
    
    private func getDefaultCompletions() -> [CompletionItem] {
        return [
            CompletionItem(text: "if", kind: .keyword),
            CompletionItem(text: "else", kind: .keyword),
            CompletionItem(text: "for", kind: .keyword),
            CompletionItem(text: "while", kind: .keyword),
            CompletionItem(text: "return", kind: .keyword),
            CompletionItem(text: "function", kind: .keyword),
            CompletionItem(text: "var", kind: .keyword),
            CompletionItem(text: "let", kind: .keyword),
            CompletionItem(text: "const", kind: .keyword),
        ]
    }
    
    private func getContextSuggestions(input: String, context: [String]) -> [CompletionItem] {
        var suggestions: [CompletionItem] = []
        
        // Look for variables/functions defined in the current context
        for item in context {
            if item.hasPrefix(input) && item != input {
                suggestions.append(CompletionItem(text: item, kind: .variable))
            }
        }
        
        return suggestions
    }
}

// ObservableObject version for SwiftUI views
public class AutocompleteEngine: ObservableObject {
    @Published var suggestions: [String] = []
    @Published var isShowing = false
    @Published var triggerPosition: NSRange = NSRange(location: 0, length: 0)
    
    private let keywordMap: [SyntaxMode: Set<String>]
    
    public init() {
        print("[Debug] AutocompleteEngine initialized (Package)")
        keywordMap = [
            .swift: Set([
                "let", "var", "func", "class", "struct", "enum", "protocol",
                "if", "else", "for", "while", "switch", "case", "default",
                "return", "break", "continue", "guard", "defer", "throw",
                "try", "catch", "finally", "do", "import", "public", "private",
                "internal", "fileprivate", "open", "static", "final", "override"
            ]),
            .javascript: Set([
                "let", "const", "var", "function", "return", "if", "else",
                "for", "while", "do", "switch", "case", "default", "break",
                "continue", "try", "catch", "finally", "throw", "new", "this",
                "class", "extends", "import", "export", "await", "async"
            ]),
            .python: Set([
                "def", "class", "return", "if", "else", "elif", "for", "while",
                "try", "except", "finally", "raise", "import", "from", "as",
                "with", "pass", "break", "continue", "global", "nonlocal"
            ]),
            .json: Set([]), // No keywords in JSON, but can suggest keys
            .html: Set([
                "div", "span", "p", "h1", "h2", "h3", "h4", "h5", "h6",
                "a", "img", "input", "button", "form", "table", "tr", "td",
                "th", "ul", "ol", "li", "head", "body", "title", "meta",
                "script", "style", "link"
            ])
        ]
    }
    
    public func analyze(text: String, cursorPosition: Int) {
        suggestions.removeAll()
        isShowing = false
        
        let safeOffset = max(0, min(cursorPosition, text.count))
        let idx = text.index(text.startIndex, offsetBy: safeOffset)
        let prefix = String(text[..<idx])
        
        let triggerChars: Set<Character> = [".", "(", "{", "[", "\"", "'", "<"]
        if let lastChar = prefix.last, triggerChars.contains(lastChar) {
            switch lastChar {
            case ".":
                let beforeDot = prefix.dropLast().components(separatedBy: " ").last
                if let className = beforeDot, ["String", "Array", "Dictionary"].contains(className) {
                    suggestions = ["count", "isEmpty", "first", "last", "append"]
                }
            case "{": suggestions = ["}"]
            case "(": suggestions = [")"]
            case "[": suggestions = ["]"]
            case "\"", "'": suggestions = [String(lastChar)]
            case "<": suggestions = [">"]
            default: break
            }
            isShowing = !suggestions.isEmpty
            if isShowing {
                triggerPosition = NSRange(location: safeOffset, length: 0)
            }
        } else {
            let lastWord = prefix.components(separatedBy: CharacterSet.alphanumerics.inverted).last ?? ""
            if lastWord.count >= 2 {
                let mode = SyntaxMode.swift // default for now
                if let keywords = keywordMap[mode] {
                    suggestions = Array(keywords.filter { $0.hasPrefix(lastWord) })
                }
                if !suggestions.isEmpty {
                    isShowing = true
                    triggerPosition = NSRange(location: safeOffset - lastWord.utf16.count, length: lastWord.utf16.count)
                }
            }
        }
    }
    
    public func insertSuggestion(_ suggestion: String) -> (String, NSRange)? {
        guard isShowing else { return nil }
        if ["}", ")", "]"].contains(suggestion) {
            return (suggestion, NSRange(location: triggerPosition.location + triggerPosition.length, length: 0))
        }
        if ["\"", "'"].contains(suggestion) {
            return (suggestion, NSRange(location: triggerPosition.location + triggerPosition.length, length: 0))
        }
        if suggestion == ">" {
            return (suggestion, NSRange(location: triggerPosition.location + triggerPosition.length, length: 0))
        }
        let replacement = suggestion + " "
        return (replacement, triggerPosition)
    }
}