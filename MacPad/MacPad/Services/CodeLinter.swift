import Foundation
import Combine

class CodeLinter: ObservableObject {
    @Published var diagnostics: [Diagnostic] = []
    
    init() {
    }
    
    func lint(_ text: String, syntaxMode: SyntaxMode) {
        diagnostics.removeAll()
        
        switch syntaxMode {
        case .swift:
            lintSwift(text)
        case .python:
            lintPython(text)
        case .javascript:
            lintJavaScript(text)
        case .json:
            lintJSON(text)
        case .html:
            lintHTML(text)
        default:
            break
        }
    }
    
    private func lintSwift(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("*") {
                continue
            }
            
            // Indentation check (4 spaces) - check this first as it's most common
            let leadingSpaces = line.prefix { $0 == " " }
            let spaceCount = leadingSpaces.count
            // Only flag if indentation is not a multiple of 4 and is not zero
            if spaceCount > 0 && spaceCount % 4 != 0 {
                diagnostics.append(Diagnostic(
                    message: "Indentation should be in multiples of 4 spaces (found \(spaceCount))",
                    line: lineNumber,
                    column: spaceCount + 1,
                    severity: .warning
                ))
            }
            
            // Unused variable - simplified check
            if trimmed.hasPrefix("let ") && !line.contains("=") {
                // Find variable name after "let "
                if let letRange = line.range(of: "let ") {
                    let afterLet = line[letRange.upperBound...]
                    let varName = String(afterLet.prefix { $0.isLetter || $0 == "_" || $0.isNumber })
                    if !varName.isEmpty {
                        diagnostics.append(Diagnostic(
                            message: "Variable '\(varName)' declared but not initialized",
                            line: lineNumber,
                            column: line.distance(from: line.startIndex, to: letRange.upperBound) + 1,
                            severity: .warning
                        ))
                    }
                }
            }
            
            // Semicolon check (optional in Swift, but flagged for style)
            if trimmed.hasSuffix(";") && !trimmed.hasPrefix("//") {
                diagnostics.append(Diagnostic(
                    message: "Semicolon not needed in Swift",
                    line: lineNumber,
                    column: line.count,
                    severity: .hint
                ))
            }
        }
    }
    
    private func lintPython(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                continue
            }
            
            // Mixed tabs and spaces
            if line.contains("\t") && line.contains(" ") {
                diagnostics.append(Diagnostic(
                    message: "Mixed tabs and spaces in indentation",
                    line: lineNumber,
                    column: 1,
                    severity: .error
                ))
            }
            
            // Indentation must be 4 spaces or tab only
            let leadingSpaces = line.prefix { $0 == " " }
            let spaceCount = leadingSpaces.count
            if spaceCount > 0 && spaceCount % 4 != 0 && !line.contains("\t") {
                diagnostics.append(Diagnostic(
                    message: "Python indentation should be multiples of 4 spaces (found \(spaceCount))",
                    line: lineNumber,
                    column: spaceCount + 1,
                    severity: .warning
                ))
            }
            
            // No trailing whitespace
            if line.hasSuffix(" ") || line.hasSuffix("\t") {
                diagnostics.append(Diagnostic(
                    message: "Trailing whitespace detected",
                    line: lineNumber,
                    column: line.count,
                    severity: .hint
                ))
            }
        }
    }
    
    private func lintJavaScript(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip empty lines and comments
            if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("*") {
                continue
            }
            
            // Missing semicolon (simplified - only flag obvious cases)
            if !trimmed.hasSuffix(";") &&
               !trimmed.hasSuffix("{") &&
               !trimmed.hasSuffix("}") &&
               !trimmed.hasSuffix(")") &&
               !trimmed.hasSuffix("]") &&
               !trimmed.hasSuffix("//") &&
               !trimmed.hasPrefix("//") &&
               (trimmed.contains("let ") || trimmed.contains("const ") || trimmed.contains("var ")) {
                diagnostics.append(Diagnostic(
                    message: "Consider adding semicolon",
                    line: lineNumber,
                    column: line.count,
                    severity: .hint
                ))
            }
            
            // Indentation check (2 or 4 spaces)
            let leadingSpaces = line.prefix { $0 == " " }
            let spaceCount = leadingSpaces.count
            if spaceCount > 0 && spaceCount % 2 != 0 && spaceCount % 4 != 0 {
                diagnostics.append(Diagnostic(
                    message: "Indentation should be multiples of 2 or 4 spaces (found \(spaceCount))",
                    line: lineNumber,
                    column: spaceCount + 1,
                    severity: .warning
                ))
            }
        }
    }
    
    private func lintJSON(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        
        // First, try to parse the JSON - if it parses successfully, it's valid JSON
        // Only do manual checks if parsing fails
        do {
            _ = try JSONSerialization.jsonObject(with: Data(text.utf8), options: [])
            // JSON is valid, only check for style issues like trailing commas
        } catch {
            // JSON parsing failed - try to find bracket/brace mismatches
            // But we need to be careful: only count braces/brackets outside of strings
            var openBraces = 0
            var openBrackets = 0
            var inString = false
            var escapeNext = false
            
            for (index, line) in lines.enumerated() {
                let lineNumber = index + 1
                for char in line {
                    if escapeNext {
                        escapeNext = false
                        continue
                    }
                    
                    if char == "\\" {
                        escapeNext = true
                        continue
                    }
                    
                    if char == "\"" {
                        inString.toggle()
                        continue
                    }
                    
                    // Only count braces/brackets outside of strings
                    if !inString {
                        switch char {
                        case "{":
                            openBraces += 1
                        case "}":
                            openBraces -= 1
                            if openBraces < 0 {
                                let column = line.distance(from: line.startIndex, to: line.firstIndex(of: "}") ?? line.startIndex) + 1
                                diagnostics.append(Diagnostic(
                                    message: "Unexpected closing brace '}'",
                                    line: lineNumber,
                                    column: column,
                                    severity: .error
                                ))
                                openBraces = 0
                            }
                        case "[":
                            openBrackets += 1
                        case "]":
                            openBrackets -= 1
                            if openBrackets < 0 {
                                let column = line.distance(from: line.startIndex, to: line.firstIndex(of: "]") ?? line.startIndex) + 1
                                diagnostics.append(Diagnostic(
                                    message: "Unexpected closing bracket ']'",
                                    line: lineNumber,
                                    column: column,
                                    severity: .error
                                ))
                                openBrackets = 0
                            }
                        default:
                            break
                        }
                    }
                }
            }
            
            // Report unclosed braces/brackets
            if openBraces > 0 {
                diagnostics.append(Diagnostic(
                    message: "Missing \(openBraces) closing brace(s)",
                    line: lines.count,
                    column: 1,
                    severity: .error
                ))
            }
            if openBrackets > 0 {
                diagnostics.append(Diagnostic(
                    message: "Missing \(openBrackets) closing bracket(s)",
                    line: lines.count,
                    column: 1,
                    severity: .error
                ))
            }
            
            // If bracket mismatches found, add the parse error too
            if openBraces == 0 && openBrackets == 0 {
                // No bracket issues, but parsing failed - report the parse error
                var errorLine = 1
                let errorMsg = error.localizedDescription
                if let range = errorMsg.range(of: "line "), 
                   let lineNumStr = errorMsg[range.upperBound...].components(separatedBy: CharacterSet.decimalDigits.inverted).first,
                   let lineNum = Int(lineNumStr) {
                    errorLine = lineNum
                }
                diagnostics.append(Diagnostic(
                    message: "Invalid JSON: \(error.localizedDescription)",
                    line: errorLine,
                    column: 1,
                    severity: .error
                ))
            }
            
            // Don't do additional checks if JSON is invalid
            return
        }
        
        // Now try to parse the JSON to catch other syntax errors
        do {
            _ = try JSONSerialization.jsonObject(with: Data(text.utf8), options: [])
        } catch {
            // Try to find the line number from the error
            var errorLine = 1
            let errorColumn = 1
            
            // Parse error message to extract position if available
            let errorMsg = error.localizedDescription
            if let range = errorMsg.range(of: "line "), 
               let lineNumStr = errorMsg[range.upperBound...].components(separatedBy: CharacterSet.decimalDigits.inverted).first,
               let lineNum = Int(lineNumStr) {
                errorLine = lineNum
            }
            
            diagnostics.append(Diagnostic(
                message: "Invalid JSON: \(error.localizedDescription)",
                line: errorLine,
                column: errorColumn,
                severity: .error
            ))
            return
        }
        
        // If JSON parsed successfully, don't flag any errors
        // JSONSerialization is the authoritative validator - if it accepts the JSON, it's valid
        // We only do manual checks when parsing fails to provide better error messages
    }
    
    private func lintHTML(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            
            // Unmatched tags
            if line.contains("<") && !line.contains(">") {
                diagnostics.append(Diagnostic(
                    message: "Unclosed tag",
                    line: lineNumber,
                    column: line.firstIndex(of: "<")?.utf16Offset(in: text) ?? 0 + 1,
                    severity: .error
                ))
            }
            
            if line.contains(">") && !line.contains("<") {
                diagnostics.append(Diagnostic(
                    message: "Unopened tag",
                    line: lineNumber,
                    column: line.firstIndex(of: ">")?.utf16Offset(in: text) ?? 0 + 1,
                    severity: .error
                ))
            }
        }
    }
}

struct Diagnostic {
    let message: String
    let line: Int
    let column: Int
    let severity: DiagnosticSeverity
    
    enum DiagnosticSeverity {
        case error, warning, hint
    }
}