import SwiftUI

struct SyntaxHighlighterView: View {
    let syntaxMode: SyntaxMode
    let text: String
    
    var body: some View {
        Group {
            if !text.isEmpty {
                Text(applySyntaxHighlighting())
                    .font(.system(size: Constants.fontSize, design: .monospaced))
            } else {
                Text("")
            }
        }
    }
    
    private func applySyntaxHighlighting() -> AttributedString {
        var attributedString = AttributedString(text)
        
        // Apply syntax patterns (Swift Regex API)
        for (pattern, color) in syntaxMode.syntaxPatterns {
            for match in text.matches(of: pattern) {
                let r = match.range
                // Safely convert Range<String.Index> -> Range<AttributedString.Index>
                if let lower = AttributedString.Index(r.lowerBound, within: attributedString),
                   let upper = AttributedString.Index(r.upperBound, within: attributedString) {
                    attributedString[lower..<upper].foregroundColor = color
                }
            }
        }
        
        return attributedString
    }
}