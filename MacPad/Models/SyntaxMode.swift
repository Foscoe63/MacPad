import Foundation
import SwiftUI   // needed for the `Color` type

enum SyntaxMode: String, CaseIterable, Codable {
    case swift, python, javascript, json, html, css
    
    // MARK: - Human‑readable names
    
    var displayName: String {
        switch self {
        case .swift:       return "Swift"
        case .python:      return "Python"
        case .javascript: return "JavaScript"
        case .json:        return "JSON"
        case .html:        return "HTML"
        case .css:         return "CSS"
        }
    }
    
    // MARK: - File extensions
    
    var fileExtensions: [String] {
        switch self {
        case .swift:       return ["swift"]
        case .python:      return ["py", "python"]
        case .javascript: return ["js", "jsx"]
        case .json:        return ["json"]
        case .html:        return ["html", "htm"]
        case .css:         return ["css"]
        }
    }
    
    // MARK: - Language keywords
    
    var keywords: Set<String> {
        switch self {
        case .swift:
            return [
                "let","var","func","class","struct","enum","protocol",
                "if","else","for","while","switch","case","default",
                "return","break","continue","guard","defer","throw",
                "try","catch","finally","do","import","public","private",
                "internal","fileprivate","open","static","final","override"
            ]
        case .python:
            return [
                "def","class","return","if","else","elif","for","while",
                "try","except","finally","raise","import","from","as",
                "with","pass","break","continue","global","nonlocal"
            ]
        case .javascript:
            return [
                "let","const","var","function","return","if","else",
                "for","while","do","switch","case","default","break",
                "continue","try","catch","finally","throw","new","this",
                "class","extends","import","export","await","async"
            ]
        case .json:
            return []
        case .html:
            return [
                "div","span","p","h1","h2","h3","h4","h5","h6",
                "a","img","input","button","form","table","tr","td",
                "th","ul","ol","li","head","body","title","meta",
                "script","style","link"
            ]
        case .css:
            return [
                "color","background","font","margin","padding","border",
                "display","position","width","height","flex","grid"
            ]
        }
    }
    
    // MARK: - Comment delimiters
    
    var commentStart: String {
        switch self {
        case .swift, .javascript:
            return "//"
        case .python:
            return "#"
        case .html:
            return "<!--"
        default:
            return ""
        }
    }
    
    var commentEnd: String {
        switch self {
        case .html:
            return "-->"
        default:
            return ""
        }
    }
    
    var lineComment: String {
        switch self {
        case .swift, .javascript:
            return "//"
        case .python:
            return "#"
        default:
            return ""
        }
    }
    
    var blockCommentStart: String {
        switch self {
        case .swift, .javascript:
            return "/*"
        default:
            return ""
        }
    }
    
    var blockCommentEnd: String {
        switch self {
        case .swift, .javascript:
            return "*/"
        default:
            return ""
        }
    }
    
    // MARK: - Delimiters used for tokenisation
    
    var delimiters: [String] {
        switch self {
        case .swift, .javascript:
            return ["(", ")", "{", "}", "[", "]", ";", ","]
        case .python:
            return ["(", ")", "{", "}", "[", "]", ":"]
        case .json:
            return ["{", "}", "[", "]", ",", ":"]
        case .html:
            // note: the double‑quote character is escaped as \" inside a Swift string literal
            return ["<", ">", "/", "\"", "'"]
        case .css:
            return []
        }
    }
    
    // MARK: - Syntax highlighting patterns
    
    var syntaxPatterns: [(pattern: Regex<String>, color: Color)] {
        let commentColor = Color.gray.opacity(0.7)
        
        switch self {
        case .swift:
            return [
                (try! Regex("//.*"), commentColor),
                // multiline block comments – use (?s) to make . match newlines
                (try! Regex("(?s)/\\*.*?\\*/"), commentColor),
                (try! Regex(#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#), Color.blue),                     // double‑quoted strings
                (try! Regex(#"'[^'\\]*'(?:\\.[^'\\]*)*'"#), Color.blue),                     // single‑quoted strings
                (try! Regex(#"\b(let|var|func|class|struct|enum|protocol|if|else|for|while|switch|case|default|return|break|continue|guard|defer|throw|try|catch|finally|do|import|public|private|internal|fileprivate|open|static|final|override)\b"#), Color.blue),
                (try! Regex(#"\b(true|false|nil)\b"#), Color.purple),
                (try! Regex(#"\b(Int|String|Double|Float|Bool|Array|Dictionary)\b"#), Color.green),
                (try! Regex(#"\b[0-9]+\b"#), Color.orange)
            ]
            
        case .python:
            return [
                (try! Regex("#.*"), commentColor),
                (try! Regex(#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#), Color.blue),
                (try! Regex(#"'[^'\\]*'(?:\\.[^'\\]*)*'"#), Color.blue),
                (try! Regex(#"\b(def|class|return|if|else|elif|for|while|try|except|finally|raise|import|from|as|with|pass|break|continue|global|nonlocal)\b"#), Color.blue),
                (try! Regex(#"\b(True|False|None)\b"#), Color.purple),
                (try! Regex(#"\b[0-9]+\b"#), Color.orange)
            ]
            
        case .javascript:
            return [
                (try! Regex("//.*"), commentColor),
                (try! Regex("(?s)/\\*.*?\\*/"), commentColor),   // multiline block comments
                (try! Regex(#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#), Color.blue),
                (try! Regex(#"'[^'\\]*'(?:\\.[^'\\]*)*'"#), Color.blue),
                (try! Regex(#"\b(let|const|var|function|return|if|else|for|while|do|switch|case|default|break|continue|try|catch|finally|throw|new|this|class|extends|import|export|await|async)\b"#), Color.blue),
                (try! Regex(#"\b(true|false|null|undefined)\b"#), Color.purple),
                (try! Regex(#"\b[0-9]+\b"#), Color.orange)
            ]
            
        case .json:
            return [
                (try! Regex(#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#), Color.blue),
                (try! Regex(#"\b[0-9]+\b"#), Color.orange),
                (try! Regex(#"\b(null|true|false)\b"#), Color.purple)
            ]
            
        case .html:
            return [
                (try! Regex("(?s)<!--.*?-->"), commentColor),   // multiline HTML comments
                (try! Regex(#"<[^>]*>"#), Color.blue),                                     // tags
                (try! Regex(#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#), Color.blue),               // attribute values in double quotes
                (try! Regex(#"'[^'\\]*'(?:\\.[^'\\]*)*'"#), Color.blue),                 // attribute values in single quotes
                (try! Regex(#"\b(div|span|p|h1|h2|h3|h4|h5|h6|a|img|input|button|form|table|tr|td|th|ul|ol|li|head|body|title|meta|script|style|link)\b"#), Color.green)
            ]
            
        case .css:
            return [
                (try! Regex("//.*"), commentColor),
                (try! Regex("(?s)/\\*.*?\\*/"), commentColor),   // multiline block comments
                (try! Regex(#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#), Color.blue),
                (try! Regex(#"'[^'\\]*'(?:\\.[^'\\]*)*'"#), Color.blue),
                (try! Regex(#"\b(color|background|font|margin|padding|border|display|position|width|height|flex|grid)\b"#), Color.blue),
                (try! Regex(#"\b#[a-fA-F0-9]{3,6}\b"#), Color.red),
                (try! Regex(#"\b[0-9]+px\b|\b[0-9]+%\b|\b[0-9]+\b"#), Color.orange)
            ]
        }
    }
}
