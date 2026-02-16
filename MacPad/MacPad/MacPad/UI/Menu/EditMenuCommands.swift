import SwiftUI
import AppKit

struct EditMenuCommands: Commands {
    private var appState: AppState { AppState.shared }
    
    var body: some Commands {
        // Ensure undo/redo are available (they should work automatically with NSTextView's UndoManager)
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                if let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
                   let undoManager = textView.undoManager {
                    undoManager.undo()
                }
            }
            .keyboardShortcut("z", modifiers: .command)
            
            Button("Redo") {
                if let textView = NSApp.keyWindow?.firstResponder as? NSTextView,
                   let undoManager = textView.undoManager {
                    undoManager.redo()
                }
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
        }
        
        CommandGroup(after: .textEditing) {
            Button("Toggle Comment", action: toggleComment)
                .keyboardShortcut("/", modifiers: .command)
            
            Divider()
            
            Button("Indent", action: indentSelection)
                .keyboardShortcut("]", modifiers: .command)
            Button("Outdent", action: outdentSelection)
                .keyboardShortcut("[", modifiers: .command)
            
            Divider()
            
            Button("Duplicate Line", action: duplicateLine)
                .keyboardShortcut("d", modifiers: [.command, .shift])
            Button("Delete Line", action: deleteLine)
                .keyboardShortcut("k", modifiers: [.command, .shift])
            
            Divider()
            
            Button("Move Line Up", action: moveLineUp)
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
            Button("Move Line Down", action: moveLineDown)
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
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
            doc.content = textView.string
            doc.isModified = true
        }
    }
    
    // MARK: - Editor Shortcuts
    
    private func indentSelection() {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
        let selectedRange = textView.selectedRange()
        let string = textView.string as NSString
        
        // Get the lines in the selection
        let lineRange = string.lineRange(for: selectedRange)
        let selectedText = string.substring(with: lineRange)
        let lines = selectedText.components(separatedBy: .newlines)
        
        // Indent each line with 4 spaces (or tab)
        let indented = lines.map { line in
            if line.isEmpty { return line }
            return "    " + line
        }.joined(separator: "\n")
        
        if textView.shouldChangeText(in: lineRange, replacementString: indented) {
            textView.replaceCharacters(in: lineRange, with: indented)
            textView.didChangeText()
            // Restore selection
            let newLength = (indented as NSString).length
            textView.setSelectedRange(NSRange(location: lineRange.location, length: newLength))
            
            if let doc = appState.getDocument(id: appState.selectedTab) {
                doc.content = textView.string
                doc.isModified = true
            }
        }
    }
    
    private func outdentSelection() {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
        let selectedRange = textView.selectedRange()
        let string = textView.string as NSString
        
        // Get the lines in the selection
        let lineRange = string.lineRange(for: selectedRange)
        let selectedText = string.substring(with: lineRange)
        let lines = selectedText.components(separatedBy: .newlines)
        
        // Outdent each line (remove 4 spaces or tab)
        let outdented = lines.map { line in
            if line.hasPrefix("    ") {
                return String(line.dropFirst(4))
            } else if line.hasPrefix("\t") {
                return String(line.dropFirst())
            } else if line.hasPrefix(" ") {
                // Remove up to 4 spaces
                var result = line
                var spacesRemoved = 0
                while result.hasPrefix(" ") && spacesRemoved < 4 {
                    result = String(result.dropFirst())
                    spacesRemoved += 1
                }
                return result
            }
            return line
        }.joined(separator: "\n")
        
        if textView.shouldChangeText(in: lineRange, replacementString: outdented) {
            textView.replaceCharacters(in: lineRange, with: outdented)
            textView.didChangeText()
            // Restore selection
            let newLength = (outdented as NSString).length
            textView.setSelectedRange(NSRange(location: lineRange.location, length: newLength))
            
            if let doc = appState.getDocument(id: appState.selectedTab) {
                doc.content = textView.string
                doc.isModified = true
            }
        }
    }
    
    private func duplicateLine() {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
        let selectedRange = textView.selectedRange()
        let string = textView.string as NSString
        
        // Get the current line
        let lineRange = string.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let lineText = string.substring(with: lineRange)
        
        // Insert the line below
        let insertLocation = lineRange.location + lineRange.length
        let insertText = lineText
        
        if textView.shouldChangeText(in: NSRange(location: insertLocation, length: 0), replacementString: insertText) {
            textView.replaceCharacters(in: NSRange(location: insertLocation, length: 0), with: insertText)
            textView.didChangeText()
            // Move cursor to the duplicated line
            let newCursorPos = insertLocation + lineRange.length
            textView.setSelectedRange(NSRange(location: newCursorPos, length: 0))
            
            if let doc = appState.getDocument(id: appState.selectedTab) {
                doc.content = textView.string
                doc.isModified = true
            }
        }
    }
    
    private func deleteLine() {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
        let selectedRange = textView.selectedRange()
        let string = textView.string as NSString
        
        // Get the current line
        let lineRange = string.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        
        if textView.shouldChangeText(in: lineRange, replacementString: "") {
            textView.replaceCharacters(in: lineRange, with: "")
            textView.didChangeText()
            // Move cursor to start of next line (or end of previous if last line)
            let newPos = min(lineRange.location, string.length - lineRange.length)
            textView.setSelectedRange(NSRange(location: newPos, length: 0))
            
            if let doc = appState.getDocument(id: appState.selectedTab) {
                doc.content = textView.string
                doc.isModified = true
            }
        }
    }
    
    private func moveLineUp() {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
        let selectedRange = textView.selectedRange()
        let string = textView.string as NSString
        
        // Get current line
        let lineRange = string.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        if lineRange.location == 0 { return } // Already at top
        
        // Get previous line
        let prevLineRange = string.lineRange(for: NSRange(location: lineRange.location - 1, length: 0))
        
        let currentLine = string.substring(with: lineRange)
        let prevLine = string.substring(with: prevLineRange)
        
        // Swap lines
        let combinedRange = NSRange(location: prevLineRange.location, length: lineRange.location + lineRange.length - prevLineRange.location)
        let swapped = currentLine + prevLine
        
        if textView.shouldChangeText(in: combinedRange, replacementString: swapped) {
            textView.replaceCharacters(in: combinedRange, with: swapped)
            textView.didChangeText()
            // Move cursor to same position in moved line
            let newPos = prevLineRange.location + (selectedRange.location - lineRange.location)
            textView.setSelectedRange(NSRange(location: newPos, length: 0))
            
            if let doc = appState.getDocument(id: appState.selectedTab) {
                doc.content = textView.string
                doc.isModified = true
            }
        }
    }
    
    private func moveLineDown() {
        guard let textView = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
        let selectedRange = textView.selectedRange()
        let string = textView.string as NSString
        
        // Get current line
        let lineRange = string.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        if lineRange.location + lineRange.length >= string.length { return } // Already at bottom
        
        // Get next line
        let nextLineStart = lineRange.location + lineRange.length
        if nextLineStart >= string.length { return }
        let nextLineRange = string.lineRange(for: NSRange(location: nextLineStart, length: 0))
        
        let currentLine = string.substring(with: lineRange)
        let nextLine = string.substring(with: nextLineRange)
        
        // Swap lines
        let combinedRange = NSRange(location: lineRange.location, length: nextLineRange.location + nextLineRange.length - lineRange.location)
        let swapped = nextLine + currentLine
        
        if textView.shouldChangeText(in: combinedRange, replacementString: swapped) {
            textView.replaceCharacters(in: combinedRange, with: swapped)
            textView.didChangeText()
            // Move cursor to same position in moved line
            let newPos = nextLineRange.location + (selectedRange.location - lineRange.location)
            textView.setSelectedRange(NSRange(location: newPos, length: 0))
            
            if let doc = appState.getDocument(id: appState.selectedTab) {
                doc.content = textView.string
                doc.isModified = true
            }
        }
    }
}


