//
//  SyntaxHighlighting.swift
//  SyntaxHighlighting
//

import Foundation
import SwiftUI

public struct SyntaxToken {
    public let text: String
    public let type: TokenType
    public let range: Range<String.Index>
    
    public init(text: String, type: TokenType, range: Range<String.Index>) {
        self.text = text
        self.type = type
        self.range = range
    }
}

public enum TokenType {
    case keyword
    case string
    case comment
    case number
    case `operator`
    case identifier
    case plain
}

public class SyntaxHighlighter {
    public init() {}
    
    public func highlight(code: String, language: String) -> [SyntaxToken] {
        // Basic syntax highlighting logic
        var tokens: [SyntaxToken] = []
        
        // This is a simplified implementation
        // In a real implementation, you'd have more sophisticated parsing
        let keywords = getKeywords(for: language)
        let lines = code.components(separatedBy: "\n")
        
        for line in lines {
            // Process each line for syntax highlighting
            tokens.append(contentsOf: tokenize(line: line, keywords: keywords))
        }
        
        return tokens
    }
    
    private func getKeywords(for language: String) -> Set<String> {
        switch language.lowercased() {
        case "swift":
            return ["class", "struct", "enum", "func", "var", "let", "if", "else", "for", "while", 
                   "import", "return", "init", "self", "static", "private", "public", "internal"]
        case "javascript", "js":
            return ["function", "var", "let", "const", "if", "else", "for", "while", 
                   "import", "export", "return", "class", "this", "new"]
        case "python", "py":
            return ["def", "class", "if", "else", "elif", "for", "while", "import", 
                   "from", "return", "try", "except", "with", "as", "lambda"]
        default:
            return []
        }
    }
    
    private func tokenize(line: String, keywords: Set<String>) -> [SyntaxToken] {
        var tokens: [SyntaxToken] = []
        var currentIndex = line.startIndex
        
        while currentIndex < line.endIndex {
            // Skip whitespace
            while currentIndex < line.endIndex && line[currentIndex].isWhitespace {
                currentIndex = line.index(after: currentIndex)
            }
            
            guard currentIndex < line.endIndex else { break }
            
            // Check for comment
            if currentIndex <= line.index(line.endIndex, offsetBy: -2) {
                let nextTwo = String(line[currentIndex..<min(line.index(currentIndex, offsetBy: 2), line.endIndex)])
                if nextTwo == "//" {
                    // Rest of line is a comment
                    let commentRange = currentIndex..<line.endIndex
                    let commentText = String(line[commentRange])
                    tokens.append(SyntaxToken(text: commentText, type: .comment, range: commentRange))
                    break
                }
            }
            
            // Check for string literals
            if line[currentIndex] == "\"" {
                let stringResult = scanStringLiteral(line: line, from: currentIndex)
                if let (stringText, newIdx) = stringResult {
                    tokens.append(SyntaxToken(text: stringText, type: .string, range: currentIndex..<newIdx))
                    currentIndex = newIdx
                    continue
                }
            }
            
            // Scan for identifiers/keywords
            if line[currentIndex].isLetter || line[currentIndex] == "_" {
                let wordResult = scanWord(line: line, from: currentIndex)
                if let (word, newIdx) = wordResult {
                    let tokenType = keywords.contains(word) ? TokenType.keyword : .identifier
                    tokens.append(SyntaxToken(text: word, type: tokenType, range: currentIndex..<newIdx))
                    currentIndex = newIdx
                    continue
                }
            }
            
            // Scan numbers
            if line[currentIndex].isNumber {
                let numberResult = scanNumber(line: line, from: currentIndex)
                if let (numberText, newIdx) = numberResult {
                    tokens.append(SyntaxToken(text: numberText, type: .number, range: currentIndex..<newIdx))
                    currentIndex = newIdx
                    continue
                }
            }
            
            // Check for operators
            if isOperatorCharacter(line[currentIndex]) {
                let opResult = scanOperator(line: line, from: currentIndex)
                if let (opText, newIdx) = opResult {
                    tokens.append(SyntaxToken(text: opText, type: .operator, range: currentIndex..<newIdx))
                    currentIndex = newIdx
                    continue
                }
            }
            
            // Move to next character if nothing matched
            currentIndex = line.index(after: currentIndex)
        }
        
        return tokens
    }
    
    private func scanStringLiteral(line: String, from start: String.Index) -> (String, String.Index)? {
        var currentIndex = start
        guard line[currentIndex] == "\"" else { return nil }
        
        let startIdx = currentIndex
        currentIndex = line.index(after: currentIndex) // skip opening quote
        
        while currentIndex < line.endIndex && line[currentIndex] != "\"" {
            // Handle escaped quotes
            if line[currentIndex] == "\\" && line.index(after: currentIndex) < line.endIndex {
                currentIndex = line.index(currentIndex, offsetBy: 2)
            } else {
                currentIndex = line.index(after: currentIndex)
            }
        }
        
        if currentIndex < line.endIndex {
            currentIndex = line.index(after: currentIndex) // include closing quote
        }
        
        return (String(line[startIdx..<currentIndex]), currentIndex)
    }
    
    private func scanWord(line: String, from start: String.Index) -> (String, String.Index)? {
        var currentIndex = start
        
        while currentIndex < line.endIndex {
            let char = line[currentIndex]
            if char.isLetter || char.isNumber || char == "_" {
                currentIndex = line.index(after: currentIndex)
            } else {
                break
            }
        }
        
        if currentIndex > start {
            return (String(line[start..<currentIndex]), currentIndex)
        }
        
        return nil
    }
    
    private func scanNumber(line: String, from start: String.Index) -> (String, String.Index)? {
        var currentIndex = start
        
        while currentIndex < line.endIndex && (line[currentIndex].isNumber || line[currentIndex] == ".") {
            currentIndex = line.index(after: currentIndex)
        }
        
        if currentIndex > start {
            return (String(line[start..<currentIndex]), currentIndex)
        }
        
        return nil
    }
    
    private func scanOperator(line: String, from start: String.Index) -> (String, String.Index)? {
        var currentIndex = start
        let operators: Set<Character> = ["+", "-", "*", "/", "=", "!", "<", ">", "&", "|", "%", "^", "~"]
        
        if operators.contains(line[currentIndex]) {
            currentIndex = line.index(after: currentIndex)
            
            // Check for double-character operators
            if currentIndex < line.endIndex {
                let doubleOp = String(line[start..<line.index(start, offsetBy: 2)])
                if ["==", "!=", "<=", ">=", "&&", "||", "->"].contains(doubleOp) {
                    currentIndex = line.index(after: currentIndex)
                }
            }
            
            return (String(line[start..<currentIndex]), currentIndex)
        }
        
        return nil
    }
    
    private func isOperatorCharacter(_ char: Character) -> Bool {
        let operators: Set<Character> = ["+", "-", "*", "/", "=", "!", "<", ">", "&", "|", "%", "^", "~", "."]
        return operators.contains(char)
    }
}