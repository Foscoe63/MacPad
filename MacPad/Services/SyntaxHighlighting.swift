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
        
        // Apply syntax patterns using NSRegularExpression
        for (patternString, color) in syntaxMode.syntaxPatterns {
            do {
                let regex = try NSRegularExpression(pattern: patternString, options: [])
                let nsString = text as NSString
                let range = NSRange(location: 0, length: nsString.length)
                regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                    if let match = match {
                        let nsRange = match.range
                        if let swiftRange = Range(nsRange, in: text) {
                            // Safely convert Range<String.Index> -> Range<AttributedString.Index>
                            if let lower = AttributedString.Index(swiftRange.lowerBound, within: attributedString),
                               let upper = AttributedString.Index(swiftRange.upperBound, within: attributedString) {
                                attributedString[lower..<upper].foregroundColor = color
                            }
                        }
                    }
                }
            } catch {
                print("[SyntaxHighlight] Invalid regex pattern '\(patternString)': \(error)")
            }
        }
        
        return attributedString
    }
}