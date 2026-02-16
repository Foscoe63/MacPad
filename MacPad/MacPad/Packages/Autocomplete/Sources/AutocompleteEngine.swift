import Foundation
import Combine

/// Autocomplete engine moved to its own Swift package.
class AutocompleteEngine: ObservableObject {
    @Published var suggestions: [String] = []
    @Published var isShowing = false
    @Published var triggerPosition: NSRange = NSRange(location: 0, length: 0)
    
    private let keywordMap: [SyntaxMode: Set<String>]
    
    init() {
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
    
    func analyze(text: String, cursorPosition: Int) {
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
    
    func insertSuggestion(_ suggestion: String) -> (String, NSRange)? {
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
