import Foundation
import Combine

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
        
        // Clamp cursor position to safe bounds and compute prefix
        let safeOffset = max(0, min(cursorPosition, text.count))
        let idx = text.index(text.startIndex, offsetBy: safeOffset)
        let prefix = String(text[..<idx])
        
        // Trigger on '.', '(', '{', '[', '"', '\'', '<'
        let triggerChars: Set<Character> = [".", "(", "{", "[", "\"", "'", "<"]
        if let lastChar = prefix.last, triggerChars.contains(lastChar) {
            // Handle immediate triggers
            switch lastChar {
            case ".":
                let beforeDot = prefix.dropLast().components(separatedBy: " ").last
                if let className = beforeDot {
                    // Simple class-based suggestions (for Swift/JS)
                    if className == "String" || className == "Array" || className == "Dictionary" {
                        suggestions = ["count", "isEmpty", "first", "last", "append"]
                    }
                }
            case "{":
                suggestions = ["}"]
            case "(":
                suggestions = [")"]
            case "[":
                suggestions = ["]"]
            case "\"", "'":
                suggestions = [String(lastChar)] // Auto-close matching quote
            case "<":
                suggestions = [">"] // Auto-close HTML tag
            default:
                break
            }
            
            isShowing = !suggestions.isEmpty
            if isShowing {
                // For immediate triggers, insert at the cursor position
                triggerPosition = NSRange(location: safeOffset, length: 0)
            }
        } else {
            // Trigger on word completion (e.g., typing 'fu' -> 'func')
            let lastWord = prefix.components(separatedBy: CharacterSet.alphanumerics.inverted).last ?? ""
            if lastWord.count >= 2 {
                let mode = SyntaxMode.swift // Default for now
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
        
        // Auto-close brackets
        if suggestion == "}" || suggestion == ")" || suggestion == "]" {
            return (suggestion, NSRange(location: triggerPosition.location + triggerPosition.length, length: 0))
        }
        
        // Auto-close quotes
        if suggestion == "\"" || suggestion == "'" {
            return (suggestion, NSRange(location: triggerPosition.location + triggerPosition.length, length: 0))
        }
        
        // Auto-close HTML tag
        if suggestion == ">" {
            return (suggestion, NSRange(location: triggerPosition.location + triggerPosition.length, length: 0))
        }
        
        // Replace word
        let replacement = suggestion + " "
        return (replacement, triggerPosition)
    }
}