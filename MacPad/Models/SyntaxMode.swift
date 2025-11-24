import Foundation
import SwiftUI   // needed for the `Color` type

enum SyntaxMode: String, CaseIterable, Codable {
    case swift, python, javascript, json, html, css, typescript, markdown, yaml, xml, shell
    
    // MARK: - Human‑readable names
    
    var displayName: String {
        switch self {
        case .swift:       return "Swift"
        case .python:      return "Python"
        case .javascript: return "JavaScript"
        case .json:        return "JSON"
        case .html:        return "HTML"
        case .css:         return "CSS"
        case .typescript:  return "TypeScript"
        case .markdown:    return "Markdown"
        case .yaml:        return "YAML"
        case .xml:         return "XML"
        case .shell:       return "Shell Script"
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
        case .typescript:  return ["ts", "tsx"]
        case .markdown:    return ["md", "markdown", "mdown", "mkd"]
        case .yaml:        return ["yaml", "yml"]
        case .xml:         return ["xml", "xsd", "xsl", "xslt"]
        case .shell:       return ["sh", "bash", "zsh", "fish", "csh", "ksh"]
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
        case .typescript:
            return [
                "let","const","var","function","return","if","else",
                "for","while","do","switch","case","default","break",
                "continue","try","catch","finally","throw","new","this",
                "class","extends","import","export","await","async",
                "interface","type","namespace","enum","public","private",
                "protected","readonly","static","abstract","implements"
            ]
        case .markdown:
            return [] // Markdown doesn't have traditional keywords
        case .yaml:
            return [] // YAML doesn't have traditional keywords
        case .xml:
            return [] // XML doesn't have traditional keywords
        case .shell:
            return [
                "if","then","else","elif","fi","for","while","do","done",
                "case","esac","function","return","export","local","readonly",
                "declare","typeset","unset","alias","source","."
            ]
        }
    }
    
    // MARK: - Comment delimiters
    
    var commentStart: String {
        switch self {
        case .swift, .javascript, .typescript:
            return "//"
        case .python, .shell, .yaml:
            return "#"
        case .html, .xml:
            return "<!--"
        default:
            return ""
        }
    }
    
    var commentEnd: String {
        switch self {
        case .html, .xml:
            return "-->"
        default:
            return ""
        }
    }
    
    var lineComment: String {
        switch self {
        case .swift, .javascript, .typescript:
            return "//"
        case .python, .shell, .yaml:
            return "#"
        default:
            return ""
        }
    }
    
    var blockCommentStart: String {
        switch self {
        case .swift, .javascript, .typescript:
            return "/*"
        default:
            return ""
        }
    }
    
    var blockCommentEnd: String {
        switch self {
        case .swift, .javascript, .typescript:
            return "*/"
        default:
            return ""
        }
    }
    
    // MARK: - Delimiters used for tokenisation
    
    var delimiters: [String] {
        switch self {
        case .swift, .javascript, .typescript:
            return ["(", ")", "{", "}", "[", "]", ";", ","]
        case .python:
            return ["(", ")", "{", "}", "[", "]", ":"]
        case .json:
            return ["{", "}", "[", "]", ",", ":"]
        case .html, .xml:
            // note: the double‑quote character is escaped as \" inside a Swift string literal
            return ["<", ">", "/", "\"", "'"]
        case .css:
            return []
        case .markdown:
            return ["#", "*", "_", "`", "[", "]", "(", ")"]
        case .yaml:
            return [":", "-", "[", "]", "{", "}", ",", "|", ">"]
        case .shell:
            return ["(", ")", "{", "}", "[", "]", ";", "|", "&", "$"]
        }
    }
    
    // MARK: - Syntax highlighting patterns
    
    // Return pattern strings instead of Regex to avoid type issues with capture groups
    var syntaxPatterns: [(pattern: String, color: Color)] {
        // Get theme colors from ThemeManager
        let theme = ThemeManager.shared.currentTheme
        let colorScheme: ColorScheme = .dark // Default to dark, could be improved to detect actual scheme
        let themeCommentColor = theme.comment.color(for: colorScheme)
        let themeKeywordColor = theme.keyword.color(for: colorScheme)
        let themeStringColor = theme.string.color(for: colorScheme)
        let themeNumberColor = theme.number.color(for: colorScheme)
        let themeTypeColor = theme.type.color(for: colorScheme)
        let constantColor = Color.purple // Keep constant color as fallback
        
        switch self {
        case .swift:
            return [
                ("//.*", themeCommentColor),
                // multiline block comments – use (?s) to make . match newlines
                ("(?s)/\\*.*?\\*/", themeCommentColor),
                (#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#, themeStringColor),                     // double‑quoted strings
                (#"'[^'\\]*'(?:\\.[^'\\]*)*'"#, themeStringColor),                     // single‑quoted strings
                (#"\b(let|var|func|class|struct|enum|protocol|if|else|for|while|switch|case|default|return|break|continue|guard|defer|throw|try|catch|finally|do|import|public|private|internal|fileprivate|open|static|final|override)\b"#, themeKeywordColor),
                (#"\b(true|false|nil)\b"#, constantColor),
                (#"\b(Int|String|Double|Float|Bool|Array|Dictionary)\b"#, themeTypeColor),
                (#"\b[0-9]+\b"#, themeNumberColor)
            ]
            
        case .python:
            return [
                ("#.*", themeCommentColor),
                (#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#, themeStringColor),
                (#"'[^'\\]*'(?:\\.[^'\\]*)*'"#, themeStringColor),
                (#"\b(def|class|return|if|else|elif|for|while|try|except|finally|raise|import|from|as|with|pass|break|continue|global|nonlocal)\b"#, themeKeywordColor),
                (#"\b(True|False|None)\b"#, constantColor),
                (#"\b[0-9]+\b"#, themeNumberColor)
            ]
            
        case .javascript:
            return [
                ("//.*", themeCommentColor),
                ("(?s)/\\*.*?\\*/", themeCommentColor),   // multiline block comments
                (#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#, themeStringColor),
                (#"'[^'\\]*'(?:\\.[^'\\]*)*'"#, themeStringColor),
                (#"\b(let|const|var|function|return|if|else|for|while|do|switch|case|default|break|continue|try|catch|finally|throw|new|this|class|extends|import|export|await|async)\b"#, themeKeywordColor),
                (#"\b(true|false|null|undefined)\b"#, constantColor),
                (#"\b[0-9]+\b"#, themeNumberColor)
            ]
            
        case .json:
            return [
                (#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#, themeStringColor),
                (#"\b[0-9]+\b"#, themeNumberColor),
                (#"\b(null|true|false)\b"#, constantColor)
            ]
            
        case .html:
            return [
                ("(?s)<!--.*?-->", themeCommentColor),   // multiline HTML comments
                (#"<[^>]*>"#, themeKeywordColor),                                     // tags
                (#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#, themeStringColor),               // attribute values in double quotes
                (#"'[^'\\]*'(?:\\.[^'\\]*)*'"#, themeStringColor),                 // attribute values in single quotes
                (#"\b(div|span|p|h1|h2|h3|h4|h5|h6|a|img|input|button|form|table|tr|td|th|ul|ol|li|head|body|title|meta|script|style|link)\b"#, themeTypeColor)
            ]
            
        case .css:
            return [
                ("//.*", themeCommentColor),
                ("(?s)/\\*.*?\\*/", themeCommentColor),   // multiline block comments
                (#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#, themeStringColor),
                (#"'[^'\\]*'(?:\\.[^'\\]*)*'"#, themeStringColor),
                (#"\b(color|background|font|margin|padding|border|display|position|width|height|flex|grid)\b"#, themeKeywordColor),
                (#"\b#[a-fA-F0-9]{3,6}\b"#, Color.red),
                (#"\b[0-9]+px\b|\b[0-9]+%\b|\b[0-9]+\b"#, themeNumberColor)
            ]
            
        case .typescript:
            return [
                ("//.*", themeCommentColor),
                ("(?s)/\\*.*?\\*/", themeCommentColor),   // multiline block comments
                (#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#, themeStringColor),
                (#"'[^'\\]*'(?:\\.[^'\\]*)*'"#, themeStringColor),
                (#"`[^`\\]*(?:\\.[^`\\]*)*`"#, themeStringColor),   // template literals
                (#"\b(let|const|var|function|return|if|else|for|while|do|switch|case|default|break|continue|try|catch|finally|throw|new|this|class|extends|import|export|await|async|interface|type|namespace|enum|public|private|protected|readonly|static|abstract|implements)\b"#, themeKeywordColor),
                (#"\b(true|false|null|undefined)\b"#, constantColor),
                (#"\b(number|string|boolean|any|void|never|unknown|object|Array|Promise)\b"#, themeTypeColor),
                (#"\b[0-9]+\b"#, themeNumberColor)
            ]
            
        case .markdown:
            return [
                ("^#{1,6}\\s+.*", themeKeywordColor),   // headers
                (#"\*\*[^*]+\*\*"#, themeKeywordColor),   // bold
                (#"\*[^*]+\*"#, themeTypeColor),   // italic
                (#"`[^`]+`"#, themeStringColor),   // inline code
                (#"```[\s\S]*?```"#, themeStringColor),   // code blocks
                (#"\[([^\]]+)\]\(([^)]+)\)"#, themeTypeColor),   // links
                (#"^\s*[-*+]\s+"#, themeKeywordColor),   // unordered list
                (#"^\s*\d+\.\s+"#, themeKeywordColor),   // ordered list
                (#">\s+.*"#, themeCommentColor),   // blockquotes
            ]
            
        case .yaml:
            return [
                ("#.*", themeCommentColor),
                (#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#, themeStringColor),
                (#"'[^'\\]*'(?:\\.[^'\\]*)*'"#, themeStringColor),
                (#"^\s*[a-zA-Z_][a-zA-Z0-9_]*:"#, themeKeywordColor),   // keys
                (#"\b(true|false|null|~)\b"#, constantColor),
                (#"\b[0-9]+\b"#, themeNumberColor),
                (#"^\s*-\s+"#, themeTypeColor),   // list items
            ]
            
        case .xml:
            return [
                ("(?s)<!--.*?-->", themeCommentColor),   // multiline XML comments
                (#"<[^>]*>"#, themeKeywordColor),   // tags
                (#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#, themeStringColor),   // attribute values in double quotes
                (#"'[^'\\]*'(?:\\.[^'\\]*)*'"#, themeStringColor),   // attribute values in single quotes
                (#"\b(xml|version|encoding|standalone|xmlns)\b"#, themeTypeColor),   // XML declarations
            ]
            
        case .shell:
            return [
                ("#.*", themeCommentColor),
                (#"\"[^\"\\]*(?:\\.[^\"\\]*)*\""#, themeStringColor),
                (#"'[^'\\]*'(?:\\.[^'\\]*)*'"#, themeStringColor),
                (#"\$[a-zA-Z_][a-zA-Z0-9_]*"#, themeTypeColor),   // variables
                (#"\$\{[^}]+\}"#, themeTypeColor),   // ${variable}
                (#"\b(if|then|else|elif|fi|for|while|do|done|case|esac|function|return|export|local|readonly|declare|typeset|unset|alias|source|\.)\b"#, themeKeywordColor),
                (#"\b(true|false)\b"#, constantColor),
                (#"\b[0-9]+\b"#, themeNumberColor),
                (#"^\s*[a-zA-Z_][a-zA-Z0-9_]*\s*="#, themeKeywordColor),   // variable assignments
            ]
        }
    }
}
