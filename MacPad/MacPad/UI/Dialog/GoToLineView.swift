import SwiftUI
import AppKit

struct GoToLineView: View {
    @Binding var isPresented: Bool
    @ObservedObject var document: Document
    @State private var lineNumberText = ""
    @FocusState private var isTextFieldFocused: Bool
    
    private var maxLineNumber: Int {
        document.content.components(separatedBy: .newlines).count
    }
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Go to Line")
                .font(.title3)
                .fontWeight(.semibold)
            
            HStack {
                Text("Line number:")
                TextField("", text: $lineNumberText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .focused($isTextFieldFocused)
                    .onSubmit {
                        goToLine()
                    }
                
                Text("of \(maxLineNumber)")
                    .foregroundStyle(.secondary)
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Go") {
                    goToLine()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 400)
        .onAppear {
            isTextFieldFocused = true
            // Pre-fill with current line if available
            if let currentLine = getCurrentLineNumber() {
                lineNumberText = "\(currentLine)"
            }
        }
    }
    
    private func getCurrentLineNumber() -> Int? {
        // Try to get current line from cursor position
        let cursorPos = document.cursorPosition
        let content = document.content
        let lines = content.components(separatedBy: .newlines)
        
        var currentPos = 0
        for (index, line) in lines.enumerated() {
            if currentPos + line.count >= cursorPos {
                return index + 1
            }
            currentPos += line.count + 1 // +1 for newline
        }
        
        return nil
    }
    
    private func goToLine() {
        guard let lineNum = Int(lineNumberText),
              lineNum > 0,
              lineNum <= maxLineNumber else {
            // Invalid line number - could show error
            return
        }
        
        let content = document.content
        let lines = content.components(separatedBy: .newlines)
        
        // Calculate character position for the start of the line
        var position = 0
        for i in 0..<(lineNum - 1) {
            if i < lines.count {
                position += lines[i].count + 1 // +1 for newline
            }
        }
        
        // Update cursor position
        document.cursorPosition = position
        
        // Post notification to scroll to line
        NotificationCenter.default.post(
            name: .mpScrollToLine,
            object: nil,
            userInfo: ["line": lineNum, "position": position]
        )
        
        isPresented = false
    }
}

