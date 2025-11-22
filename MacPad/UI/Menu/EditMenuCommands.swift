import SwiftUI
import AppKit

struct EditMenuCommands: Commands {
    private var appState: AppState { AppState.shared }
    
    var body: some Commands {
        CommandGroup(after: .textEditing) {
            Button("Toggle Comment", action: toggleComment)
                .keyboardShortcut("/", modifiers: .command)
        }
    }
    
    private func toggleComment() {
        guard let doc = appState.getDocument(id: appState.selectedTab),
              let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
        
        let selectedRange = textView.selectedRange()
        guard selectedRange.length > 0 else { return }
        
        let content = doc.content
        let nsContent = content as NSString
        let selectedText = nsContent.substring(with: selectedRange)
        
        let syntaxMode = doc.syntaxMode
        let lineComment = syntaxMode.lineComment
        let blockStart = syntaxMode.blockCommentStart
        let blockEnd = syntaxMode.blockCommentEnd
        
        // Determine if we should use block comments or line comments
        let useBlockComments = !blockStart.isEmpty && selectedText.contains("\n")
        
        var modifiedText: String
        var newRange: NSRange
        
        if useBlockComments {
            // Block comment logic
            let trimmed = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix(blockStart) && trimmed.hasSuffix(blockEnd) {
                // Uncomment: remove block comment markers
                let startIdx = trimmed.index(trimmed.startIndex, offsetBy: blockStart.count)
                let endIdx = trimmed.index(trimmed.endIndex, offsetBy: -blockEnd.count)
                modifiedText = String(trimmed[startIdx..<endIdx])
                newRange = NSRange(location: selectedRange.location, length: modifiedText.count)
            } else {
                // Comment: add block comment markers
                modifiedText = blockStart + selectedText + blockEnd
                newRange = NSRange(location: selectedRange.location, length: modifiedText.count)
            }
        } else {
            // Line comment logic
            let lines = selectedText.components(separatedBy: .newlines)
            let allCommented = !lines.isEmpty && lines.allSatisfy { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                return trimmed.isEmpty || trimmed.hasPrefix(lineComment)
            }
            
            if allCommented && !lineComment.isEmpty {
                // Uncomment: remove line comment markers
                modifiedText = lines.map { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty {
                        return line
                    }
                    if trimmed.hasPrefix(lineComment) {
                        // Find the position of the comment marker in the original line
                        if let commentIndex = line.range(of: lineComment) {
                            var result = line
                            result.removeSubrange(commentIndex)
                            // Remove one space after comment if present
                            if result.hasPrefix(" ") {
                                result = String(result.dropFirst())
                            }
                            return result
                        }
                    }
                    return line
                }.joined(separator: "\n")
                newRange = NSRange(location: selectedRange.location, length: modifiedText.count)
            } else if !lineComment.isEmpty {
                // Comment: add line comment markers
                modifiedText = lines.map { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.isEmpty {
                        return line
                    }
                    // Find the first non-whitespace character to preserve indentation
                    let leadingWhitespace = String(line.prefix { $0.isWhitespace })
                    return leadingWhitespace + lineComment + " " + trimmed
                }.joined(separator: "\n")
                newRange = NSRange(location: selectedRange.location, length: modifiedText.count)
            } else {
                return // No comment support for this language
            }
        }
        
        // Apply the change
        if textView.shouldChangeText(in: selectedRange, replacementString: modifiedText) {
            textView.replaceCharacters(in: selectedRange, with: modifiedText)
            textView.didChangeText()
            textView.setSelectedRange(newRange)
            
            // Update document content
            doc.content = textView.string
            doc.isModified = true
        }
    }
}


