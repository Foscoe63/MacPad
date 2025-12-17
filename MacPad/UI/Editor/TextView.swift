import SwiftUI
import Foundation

struct TextView: View {
    @ObservedObject var document: Document
    // Initialize text from document content to ensure it's set on state restoration
    @State private var text: String
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
    
    // Initialize with document content to ensure text is set on state restoration
    init(document: Document) {
        self.document = document
        _text = State(initialValue: document.content)
    }
    
    var body: some View {
        CocoaTextView(
            text: Binding(
                get: { 
                    // Always return document.content to ensure it reflects current state (handles state restoration)
                    // Also sync text state to avoid unnecessary re-renders
                    if text != document.content {
                        text = document.content
                    }
                    return document.content
                },
                set: { newValue in
                    text = newValue
                    if document.content != newValue {
                        document.content = newValue
                        document.isModified = true
                        if lintingEnabled {
                            linter.lint(newValue, syntaxMode: document.syntaxMode)
                        }
                    }
                }
            ),
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
                // This callback is handled by the Binding setter above
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
            // Ensure text is synced with document content on appear (handles state restoration)
            if text != document.content {
                text = document.content
            }
            if lintingEnabled {
                linter.lint(document.content, syntaxMode: document.syntaxMode)
            }
        }
        .task(id: document.id) {
            // Task ensures text is synced when document changes (handles state restoration timing issues)
            // Use a small delay to ensure document content is fully loaded
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms delay
            if text != document.content {
                await MainActor.run {
                    text = document.content
                }
            }
        }
        .onChange(of: document.content) { oldValue, newValue in
            // Update text when document content changes (handles tab switching and external updates)
            if text != newValue {
                text = newValue
            }
        }
        .onChange(of: document.id) { oldValue, newValue in
            // When document ID changes (tab switch), ensure text is synced
            if text != document.content {
                text = document.content
            }
        }
        .onChange(of: document.syntaxMode) { _, _ in
            if lintingEnabled {
                linter.lint(text, syntaxMode: document.syntaxMode)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
