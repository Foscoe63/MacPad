//
//  CodeLinter.swift
//  CodeLinter
//

import Foundation

public struct LintIssue {
    public let line: Int
    public let column: Int
    public let severity: Severity
    public let message: String
    public let rule: String
    
    public init(line: Int, column: Int, severity: Severity, message: String, rule: String) {
        self.line = line
        self.column = column
        self.severity = severity
        self.message = message
        self.rule = rule
    }
}

public enum Severity: String, CaseIterable {
    case hint = "hint"
    case info = "info"
    case warning = "warning"
    case error = "error"
    
    public var priority: Int {
        switch self {
        case .hint: return 0
        case .info: return 1
        case .warning: return 2
        case .error: return 3
        }
    }
}

public struct LintRule {
    public let name: String
    public let description: String
    public let severity: Severity
    
    public init(name: String, description: String, severity: Severity) {
        self.name = name
        self.description = description
        self.severity = severity
    }
}

public class CodeLinter {
    public init() {}
    
    public func lint(code: String, language: String) -> [LintIssue] {
        var issues: [LintIssue] = []
        
        switch language.lowercased() {
        case "swift":
            issues.append(contentsOf: lintSwift(code: code))
        case "javascript", "js":
            issues.append(contentsOf: lintJavaScript(code: code))
        case "python", "py":
            issues.append(contentsOf: lintPython(code: code))
        default:
            issues.append(contentsOf: lintGeneric(code: code))
        }
        
        return issues
    }
    
    private func lintSwift(code: String) -> [LintIssue] {
        var issues: [LintIssue] = []
        let lines = code.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            
            // Check for lines that are too long (over 100 characters)
            if line.count > 100 {
                issues.append(LintIssue(
                    line: lineNumber,
                    column: 101,
                    severity: .warning,
                    message: "Line is longer than 100 characters",
                    rule: "line_length"
                ))
            }
            
            // Check for trailing whitespace
            if line.hasSuffix(" ") || line.hasSuffix("\t") {
                issues.append(LintIssue(
                    line: lineNumber,
                    column: line.count,
                    severity: .warning,
                    message: "Trailing whitespace",
                    rule: "trailing_whitespace"
                ))
            }
            
            // Check for force unwrapping
            if line.contains("!") && (line.contains("var") || line.contains("let")) {
                if line.contains("!") && !line.contains("!= ") && !line.contains(" ! ") {
                    issues.append(LintIssue(
                        line: lineNumber,
                        column: line.firstIndex(of: "!")?.utf16Offset(in: line) ?? 0,
                        severity: .warning,
                        message: "Force unwrap (!) detected",
                        rule: "force_unwrap"
                    ))
                }
            }
        }
        
        return issues
    }
    
    private func lintJavaScript(code: String) -> [LintIssue] {
        var issues: [LintIssue] = []
        let lines = code.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            
            // Check for lines that are too long
            if line.count > 100 {
                issues.append(LintIssue(
                    line: lineNumber,
                    column: 101,
                    severity: .warning,
                    message: "Line is longer than 100 characters",
                    rule: "line_length"
                ))
            }
            
            // Check for trailing whitespace
            if line.hasSuffix(" ") || line.hasSuffix("\t") {
                issues.append(LintIssue(
                    line: lineNumber,
                    column: line.count,
                    severity: .warning,
                    message: "Trailing whitespace",
                    rule: "trailing_whitespace"
                ))
            }
            
            // Check for semicolon usage (if preferred style includes semicolons)
            if line.trimmingCharacters(in: .whitespaces).hasSuffix(";") == false &&
               !line.trimmingCharacters(in: .whitespaces).isEmpty &&
               !line.contains("{") &&
               !line.contains("}") &&
               !line.contains("if") &&
               !line.contains("else") &&
               !line.contains("for") &&
               !line.contains("while") &&
               !line.contains("function") {
                issues.append(LintIssue(
                    line: lineNumber,
                    column: line.count,
                    severity: .info,
                    message: "Missing semicolon",
                    rule: "missing_semicolon"
                ))
            }
        }
        
        return issues
    }
    
    private func lintPython(code: String) -> [LintIssue] {
        var issues: [LintIssue] = []
        let lines = code.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            
            // Check for lines that are too long
            if line.count > 100 {
                issues.append(LintIssue(
                    line: lineNumber,
                    column: 101,
                    severity: .warning,
                    message: "Line is longer than 100 characters",
                    rule: "line_length"
                ))
            }
            
            // Check for trailing whitespace
            if line.hasSuffix(" ") || line.hasSuffix("\t") {
                issues.append(LintIssue(
                    line: lineNumber,
                    column: line.count,
                    severity: .warning,
                    message: "Trailing whitespace",
                    rule: "trailing_whitespace"
                ))
            }
            
            // Check indentation (should be multiples of 4 spaces)
            let leadingSpaces = line.count - line.trimmingCharacters(in: .whitespacesAndNewlines).count
            if leadingSpaces > 0 && leadingSpaces % 4 != 0 {
                issues.append(LintIssue(
                    line: lineNumber,
                    column: 1,
                    severity: .warning,
                    message: "Indentation is not a multiple of 4 spaces",
                    rule: "indentation"
                ))
            }
        }
        
        return issues
    }
    
    private func lintGeneric(code: String) -> [LintIssue] {
        var issues: [LintIssue] = []
        let lines = code.components(separatedBy: "\n")
        
        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            
            // Check for lines that are too long
            if line.count > 120 {
                issues.append(LintIssue(
                    line: lineNumber,
                    column: 121,
                    severity: .warning,
                    message: "Line is longer than 120 characters",
                    rule: "line_length"
                ))
            }
            
            // Check for trailing whitespace
            if line.hasSuffix(" ") || line.hasSuffix("\t") {
                issues.append(LintIssue(
                    line: lineNumber,
                    column: line.count,
                    severity: .warning,
                    message: "Trailing whitespace",
                    rule: "trailing_whitespace"
                ))
            }
        }
        
        return issues
    }
}