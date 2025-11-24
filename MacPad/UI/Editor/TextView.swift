import SwiftUI
import Foundation

struct TextView: View {
    @ObservedObject var document: Document
    @State private var text = ""
    @StateObject private var linter = CodeLinter()
    @AppStorage("editor.fontSize") private var prefFontSize: Double = 14
    @AppStorage("editor.lineSpacing") private var prefLineSpacing: Double = 2.0
    @AppStorage("editor.showLineNumbers") private var prefShowLineNumbers: Bool = true
    @AppStorage("editor.wordWrap") private var wordWrap: Bool = true
    @AppStorage("application.textMode") private var textMode: String = "plain" // plain, rich
    @AppStorage("advanced.linting") private var lintingEnabled: Bool = true
    @AppStorage("editor.goToDefinition") private var goToDefinitionEnabled: Bool = true
    
    // Treat documents with attributed content as Rich regardless of global pref, so HTML/RTF show colors
    var isRichText: Bool { textMode.lowercased() == "rich" || document.attributedContent != nil }
    
    var body: some View {
        CocoaTextView(
            text: $text,
            fontSize: CGFloat(prefFontSize),
            lineSpacing: CGFloat(prefLineSpacing),
            showLineNumbers: prefShowLineNumbers,
            wordWrap: wordWrap,
            isRichText: isRichText,
            attributed: isRichText ? document.attributedContent : nil,
            syntaxMode: document.syntaxMode,
            fileExtension: document.path?.pathExtension,
            lintingEnabled: lintingEnabled,
            goToDefinitionEnabled: goToDefinitionEnabled,
            linter: linter,
            onTextChange: { newValue in
                if document.content != newValue {
                    document.content = newValue
                    document.isModified = true
                    // Trigger linting when enabled
                    if lintingEnabled {
                        linter.lint(newValue, syntaxMode: document.syntaxMode)
                    }
                }
            },
            onAttributedChange: { newAttr in
                if isRichText {
                    document.attributedContent = newAttr
                    document.isModified = true
                }
            },
            onCursorChange: { line, column, position in
                // Defer updates to avoid publishing during view updates
                Task { @MainActor in
                    document.cursorLine = line
                    document.cursorColumn = column
                    document.cursorPosition = position
                }
            }
        )
        .onAppear {
            text = document.content
            if lintingEnabled {
                linter.lint(document.content, syntaxMode: document.syntaxMode)
            }
        }
        .onChange(of: document.content) { oldValue, newValue in
            if text != newValue { text = newValue }
        }
        .onChange(of: document.syntaxMode) { _, _ in
            if lintingEnabled {
                linter.lint(text, syntaxMode: document.syntaxMode)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
