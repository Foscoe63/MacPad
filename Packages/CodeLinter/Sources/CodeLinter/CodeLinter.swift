import Foundation
import Combine

/// Linter moved into its own Swift package.
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
    
    // MARK: - Language specific linting (unchanged from original implementation)
    private func lintSwift(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("*") { continue }
            let leadingSpaces = line.prefix { $0 == " " }
            let spaceCount = leadingSpaces.count
            if spaceCount > 0 && spaceCount % 4 != 0 {
                diagnostics.append(Diagnostic(message: "Indentation should be in multiples of 4 spaces (found \(spaceCount))", line: lineNumber, column: spaceCount + 1, severity: .warning))
            }
            if trimmed.hasPrefix("let ") && !line.contains("=") {
                if let letRange = line.range(of: "let ") {
                    let afterLet = line[letRange.upperBound...]
                    let varName = String(afterLet.prefix { $0.isLetter || $0 == "_" || $0.isNumber })
                    if !varName.isEmpty {
                        diagnostics.append(Diagnostic(message: "Variable '\(varName)' declared but not initialized", line: lineNumber, column: line.distance(from: line.startIndex, to: letRange.upperBound) + 1, severity: .warning))
                    }
                }
            }
            if trimmed.hasSuffix(";") && !trimmed.hasPrefix("//") {
                diagnostics.append(Diagnostic(message: "Semicolon not needed in Swift", line: lineNumber, column: line.count, severity: .hint))
            }
        }
    }
    
    private func lintPython(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            if line.contains("\t") && line.contains(" ") {
                diagnostics.append(Diagnostic(message: "Mixed tabs and spaces in indentation", line: lineNumber, column: 1, severity: .error))
            }
            let leadingSpaces = line.prefix { $0 == " " }
            let spaceCount = leadingSpaces.count
            if spaceCount > 0 && spaceCount % 4 != 0 && !line.contains("\t") {
                diagnostics.append(Diagnostic(message: "Python indentation should be multiples of 4 spaces (found \(spaceCount))", line: lineNumber, column: spaceCount + 1, severity: .warning))
            }
            if line.hasSuffix(" ") || line.hasSuffix("\t") {
                diagnostics.append(Diagnostic(message: "Trailing whitespace detected", line: lineNumber, column: line.count, severity: .hint))
            }
        }
    }
    
    private func lintJavaScript(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty || trimmed.hasPrefix("//") || trimmed.hasPrefix("*") { continue }
            if !trimmed.hasSuffix(";") &&
                !trimmed.hasSuffix("{") &&
                !trimmed.hasSuffix("}") &&
                !trimmed.hasSuffix(")") &&
                !trimmed.hasSuffix("]") &&
                !trimmed.hasSuffix("//") &&
                !trimmed.hasPrefix("//") &&
                (trimmed.contains("let ") || trimmed.contains("const ") || trimmed.contains("var ")) {
                diagnostics.append(Diagnostic(message: "Consider adding semicolon", line: lineNumber, column: line.count, severity: .hint))
            }
            let leadingSpaces = line.prefix { $0 == " " }
            let spaceCount = leadingSpaces.count
            if spaceCount > 0 && spaceCount % 2 != 0 && spaceCount % 4 != 0 {
                diagnostics.append(Diagnostic(message: "Indentation should be multiples of 2 or 4 spaces (found \(spaceCount))", line: lineNumber, column: spaceCount + 1, severity: .warning))
            }
        }
    }
    
    private func lintJSON(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        do {
            _ = try JSONSerialization.jsonObject(with: Data(text.utf8), options: [])
        } catch {
            var openBraces = 0, openBrackets = 0
            var inString = false, escapeNext = false
            for (idx, line) in lines.enumerated() {
                let lineNumber = idx + 1
                for char in line {
                    if escapeNext { escapeNext = false; continue }
                    if char == "\\" { escapeNext = true; continue }
                    if char == "\"" { inString.toggle(); continue }
                    if !inString {
                        switch char {
                        case "{": openBraces += 1
                        case "}":
                            openBraces -= 1
                            if openBraces < 0 {
                                let column = line.distance(from: line.startIndex, to: line.firstIndex(of: "}") ?? line.startIndex) + 1
                                diagnostics.append(Diagnostic(message: "Unexpected closing brace '}'", line: lineNumber, column: column, severity: .error))
                                openBraces = 0
                            }
                        case "[": openBrackets += 1
                        case "]":
                            openBrackets -= 1
                            if openBrackets < 0 {
                                let column = line.distance(from: line.startIndex, to: line.firstIndex(of: "]") ?? line.startIndex) + 1
                                diagnostics.append(Diagnostic(message: "Unexpected closing bracket ']'", line: lineNumber, column: column, severity: .error))
                                openBrackets = 0
                            }
                        default: break
                        }
                    }
                }
            }
            if openBraces > 0 {
                diagnostics.append(Diagnostic(message: "Missing \(openBraces) closing brace(s)", line: lines.count, column: 1, severity: .error))
            }
            if openBrackets > 0 {
                diagnostics.append(Diagnostic(message: "Missing \(openBrackets) closing bracket(s)", line: lines.count, column: 1, severity: .error))
            }
            var errorLine = 1
            let errMsg = error.localizedDescription
            if let range = errMsg.range(of: "line ") {
                let numStr = errMsg[range.upperBound...].components(separatedBy: CharacterSet.decimalDigits.inverted).first ?? "1"
                errorLine = Int(numStr) ?? 1
            }
            diagnostics.append(Diagnostic(message: "Invalid JSON: \(error.localizedDescription)", line: errorLine, column: 1, severity: .error))
            return
        }
    }
    
    private func lintHTML(_ text: String) {
        let lines = text.components(separatedBy: .newlines)
        for (idx, line) in lines.enumerated() {
            let lineNumber = idx + 1
            if line.contains("<") && !line.contains(">") {
                diagnostics.append(Diagnostic(message: "Unclosed tag", line: lineNumber, column: line.firstIndex(of: "<")?.utf16Offset(in: text) ?? 0 + 1, severity: .error))
            }
            if line.contains(">") && !line.contains("<") {
                diagnostics.append(Diagnostic(message: "Unopened tag", line: lineNumber, column: line.firstIndex(of: ">")?.utf16Offset(in: text) ?? 0 + 1, severity: .error))
            }
        }
    }
}

struct Diagnostic {
    let message: String
    let line: Int
    let column: Int
    let severity: DiagnosticSeverity
    enum DiagnosticSeverity { case error, warning, hint }
}
