import SwiftUI
import AppKit

struct FindReplaceSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var document: Document
    @State private var findText = ""
    @State private var replaceText = ""
    @State private var useRegex = false
    @State private var matchCase = false
    @State private var wholeWords = false
    @State private var searchResults: [NSRange] = []
    @State private var currentMatchIndex: Int = -1
    @State private var errorMessage: String? = nil
    @State private var isSearching = false
    @State private var sheetOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @State private var windowStartOrigin: CGPoint? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {

            // Header - draggable area
            HStack {
                Text("Find and Replace")
                    .font(.title3)
                    .fontWeight(.semibold)
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Close")
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        sheetOffset = CGSize(width: sheetOffset.width + value.translation.width,
                                            height: sheetOffset.height + value.translation.height)
                    }
                    .onEnded { _ in
                        // No additional cleanup needed
                    }
            )
            
            // Find field
            HStack {
                Text("Find:")
                    .frame(width: 80, alignment: .leading)
                TextField("Enter text to find", text: $findText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        performSearch()
                    }
                .accessibilityIdentifier("findField")
            }
            
            // Replace field
            HStack {
                Text("Replace:")
                    .frame(width: 80, alignment: .leading)
                TextField("Replacement text", text: $replaceText)
                    .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("replaceField")
            }
            
            // Options
            VStack(alignment: .leading, spacing: 8) {
                Text("Options")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 16) {
                    Toggle("Regex", isOn: $useRegex)
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("regexToggle")
                    
                    Toggle("Match Case", isOn: $matchCase)
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("matchCaseToggle")
                    
                    Toggle("Whole Words", isOn: $wholeWords)
                        .toggleStyle(.switch)
                        .accessibilityIdentifier("wholeWordsToggle")
                }
            }
            
            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            // Match count
            if !searchResults.isEmpty {
                Text("Found \(searchResults.count) match\(searchResults.count == 1 ? "" : "es")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Buttons
            HStack {
                Button("Cancel") {
                    clearHighlights()
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Button("Close") {
                    clearHighlights()
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Search Only") {
                    performSearch()
                }
                .buttonStyle(.borderedProminent)
                .disabled(findText.isEmpty || isSearching)
                
                Button("Replace") {
                    performReplacement()
                }
                .buttonStyle(.borderedProminent)
                .disabled(findText.isEmpty || isSearching)
                
                Button("Replace All") {
                    performAllReplacements()
                }
                .buttonStyle(.borderedProminent)
                .disabled(findText.isEmpty || isSearching)
                .accessibilityIdentifier("replaceAllButton")
            }
        }
        
                .offset(sheetOffset)
                .padding()
        .frame(minWidth: 400, idealWidth: 520, maxWidth: .infinity,
               minHeight: 250, idealHeight: 300, maxHeight: .infinity)
        .background(SheetWindowDraggable())
        .onAppear {
            // Configure the sheet window to be draggable
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                makeSheetDraggable()
            }
        }
        .onDisappear {
            clearHighlights()
        }
    }
    
    // MARK: - Search Functions
    
    private func performSearch() {
        guard !findText.isEmpty else {
            clearHighlights()
            return
        }
        
        // Prevent multiple simultaneous searches
        guard !isSearching else { return }
        isSearching = true
        defer { isSearching = false }
        
        errorMessage = nil
        searchResults = []
        currentMatchIndex = -1
        
        guard let textView = getCurrentTextView(),
              let storage = textView.textStorage else {
            errorMessage = "No text view available"
            return
        }
        
        // Use the actual text view content, not document.content
        let content = storage.string
        guard !content.isEmpty else {
            errorMessage = "Document is empty"
            return
        }
        
        var matches: [NSRange] = []
        
        if useRegex {
            do {
                let options: NSRegularExpression.Options = matchCase ? [] : .caseInsensitive
                let regex = try NSRegularExpression(pattern: findText, options: options)
                let range = NSRange(location: 0, length: content.utf16.count)
                
                regex.enumerateMatches(in: content, options: [], range: range) { match, _, _ in
                    if let match = match {
                        matches.append(match.range)
                    }
                }
            } catch {
                errorMessage = "Invalid regex pattern: \(error.localizedDescription)"
                return
            }
        } else {
            if wholeWords {
                // For whole words, use regex with word boundaries
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: findText) + "\\b"
                do {
                    let regexOptions: NSRegularExpression.Options = matchCase ? [] : .caseInsensitive
                    let regex = try NSRegularExpression(pattern: pattern, options: regexOptions)
                    let range = NSRange(location: 0, length: content.utf16.count)
                    regex.enumerateMatches(in: content, options: [], range: range) { match, _, _ in
                        if let match = match {
                            matches.append(match.range)
                        }
                    }
                } catch {
                    errorMessage = "Error searching: \(error.localizedDescription)"
                    return
                }
            } else {
                let options: NSString.CompareOptions = matchCase ? [] : .caseInsensitive
                var startIndex = content.startIndex
                while let range = content.range(of: findText, options: options, range: startIndex..<content.endIndex) {
                    let nsRange = NSRange(range, in: content)
                    matches.append(nsRange)
                    startIndex = range.upperBound
                    if startIndex >= content.endIndex { break }
                }
            }
        }
        
        searchResults = matches
        
        if !matches.isEmpty {
            highlightMatches(in: textView)
            // Scroll to first match
            if let firstRange = matches.first {
                textView.scrollRangeToVisible(firstRange)
                textView.setSelectedRange(firstRange)
            }
            errorMessage = nil
        } else {
            clearHighlights()
            errorMessage = "No matches found"
        }
    }
    
    private func highlightMatches(in textView: NSTextView) {
        guard let storage = textView.textStorage else { return }
        
        // Clear previous highlights first
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.removeAttribute(.backgroundColor, range: fullRange)
        
        // Highlight all matches
        let highlightColor = NSColor.systemYellow.withAlphaComponent(0.3)
        for range in searchResults {
            if range.location + range.length <= storage.length {
                storage.addAttribute(.backgroundColor, value: highlightColor, range: range)
            }
        }
        
        textView.needsDisplay = true
    }
    
    private func clearHighlights() {
        guard let textView = getCurrentTextView(),
              let storage = textView.textStorage else { return }
        
        let fullRange = NSRange(location: 0, length: storage.length)
        storage.removeAttribute(.backgroundColor, range: fullRange)
        textView.needsDisplay = true
        searchResults = []
        currentMatchIndex = -1
    }
    
    // MARK: - Replace Functions
    
    private func performReplacement() {
        guard !findText.isEmpty else { return }
        guard !isSearching else { return }
        isSearching = true
        defer { isSearching = false }
        
        guard let textView = getCurrentTextView(),
              let storage = textView.textStorage else {
            errorMessage = "No text view available"
            return
        }
        
        let content = storage.string
        var rangeToReplace: NSRange?
        
        if useRegex {
            do {
                let options: NSRegularExpression.Options = matchCase ? [] : .caseInsensitive
                let regex = try NSRegularExpression(pattern: findText, options: options)
                let searchRange = NSRange(location: 0, length: content.utf16.count)
                
                if let firstMatch = regex.firstMatch(in: content, options: [], range: searchRange) {
                    rangeToReplace = firstMatch.range
                }
            } catch {
                errorMessage = "Invalid regex pattern: \(error.localizedDescription)"
                return
            }
        } else {
            let options: NSString.CompareOptions = matchCase ? [] : .caseInsensitive
            if wholeWords {
                // For whole words, find the first match using regex
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: findText) + "\\b"
                do {
                    let regexOptions: NSRegularExpression.Options = matchCase ? [] : .caseInsensitive
                    let regex = try NSRegularExpression(pattern: pattern, options: regexOptions)
                    let searchRange = NSRange(location: 0, length: content.utf16.count)
                    if let firstMatch = regex.firstMatch(in: content, options: [], range: searchRange) {
                        rangeToReplace = firstMatch.range
                    }
                } catch {
                    // Fallback to simple search
                    if let swiftRange = content.range(of: findText, options: options) {
                        rangeToReplace = NSRange(swiftRange, in: content)
                    }
                }
            } else {
                if let swiftRange = content.range(of: findText, options: options) {
                    rangeToReplace = NSRange(swiftRange, in: content)
                }
            }
        }
        
        if let range = rangeToReplace {
            if textView.shouldChangeText(in: range, replacementString: replaceText) {
                storage.replaceCharacters(in: range, with: replaceText)
                textView.didChangeText()
                
                // Update document content
                document.content = storage.string
                document.isModified = true
                
                // Re-search to update highlights
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    performSearch()
                }
            }
        } else {
            errorMessage = "No match found to replace"
        }
    }
    
    private func performAllReplacements() {
        guard !findText.isEmpty else { return }
        guard !isSearching else { return }
        isSearching = true
        defer { isSearching = false }
        
        guard let textView = getCurrentTextView(),
              let storage = textView.textStorage else {
            errorMessage = "No text view available"
            return
        }
        
        let content = storage.string
        var updatedContent = content
        
        if useRegex {
            do {
                let options: NSRegularExpression.Options = matchCase ? [] : .caseInsensitive
                let regex = try NSRegularExpression(pattern: findText, options: options)
                let range = NSRange(location: 0, length: content.utf16.count)
                updatedContent = regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: replaceText)
            } catch {
                errorMessage = "Invalid regex pattern: \(error.localizedDescription)"
                return
            }
        } else {
            if wholeWords {
                // For whole words, use regex replacement
                let pattern = "\\b" + NSRegularExpression.escapedPattern(for: findText) + "\\b"
                do {
                    let regexOptions: NSRegularExpression.Options = matchCase ? [] : .caseInsensitive
                    let regex = try NSRegularExpression(pattern: pattern, options: regexOptions)
                    let range = NSRange(location: 0, length: content.utf16.count)
                    updatedContent = regex.stringByReplacingMatches(in: content, options: [], range: range, withTemplate: replaceText)
                } catch {
                    errorMessage = "Error replacing: \(error.localizedDescription)"
                    return
                }
            } else {
                let options: NSString.CompareOptions = matchCase ? [] : .caseInsensitive
                var startIndex = updatedContent.startIndex
                var replacementCount = 0
                while let range = updatedContent.range(of: findText, options: options, range: startIndex..<updatedContent.endIndex) {
                    updatedContent.replaceSubrange(range, with: replaceText)
                    replacementCount += 1
                    // Move start index forward
                    let newStart = updatedContent.index(range.lowerBound, offsetBy: replaceText.count)
                    if newStart >= updatedContent.endIndex { break }
                    startIndex = newStart
                }
                
                if replacementCount == 0 {
                    errorMessage = "No matches found to replace"
                    return
                }
            }
        }
        
        if updatedContent != content {
            let fullRange = NSRange(location: 0, length: content.utf16.count)
            if textView.shouldChangeText(in: fullRange, replacementString: updatedContent) {
                storage.replaceCharacters(in: fullRange, with: updatedContent)
                textView.didChangeText()
                
                // Update document content
                document.content = updatedContent
                document.isModified = true
                
                // Clear highlights after replace all
                clearHighlights()
                errorMessage = nil
            }
        } else {
            errorMessage = "No matches found to replace"
        }
    }
    
    // MARK: - Helper Functions
    
    private func getCurrentTextView() -> NSTextView? {
        // First, try to find the main window (not the sheet window)
        let mainWindow = NSApp.windows.first { window in
            // Skip sheet windows and find the main editor window
            !window.isSheet && window.isVisible && window.contentView != nil
        }
        
        // Try to get text view from main window's content view
        if let mainWindow = mainWindow {
            // Search recursively for NSTextView
            if let textView = findTextView(in: mainWindow.contentView) {
                return textView
            }
        }
        
        // Fallback: try key window (but skip if it's a sheet)
        if let keyWindow = NSApp.keyWindow, !keyWindow.isSheet {
            if let textView = findTextView(in: keyWindow.contentView) {
                return textView
            }
        }
        
        // Last resort: search all windows
        for window in NSApp.windows {
            if window.isSheet { continue }
            if let textView = findTextView(in: window.contentView) {
                return textView
            }
        }
        
        return nil
    }
    
    private func findTextView(in view: NSView?) -> NSTextView? {
        guard let view = view else { return nil }
        
        // Check if this view is an NSTextView
        if let textView = view as? NSTextView {
            return textView
        }
        
        // Check if this is an NSScrollView containing an NSTextView
        if let scrollView = view as? NSScrollView,
           let textView = scrollView.documentView as? NSTextView {
            return textView
        }
        
        // Recursively search subviews
        for subview in view.subviews {
            if let textView = findTextView(in: subview) {
                return textView
            }
        }
        
        return nil
    }
    
    // MARK: - Window Dragging
    
    private func makeSheetDraggable() {
        // Find the sheet window
        if let sheetWindow = findSheetWindow() {
            sheetWindow.isMovable = true
            sheetWindow.isMovableByWindowBackground = true
        }
    }
    
    private func findSheetWindow() -> NSWindow? {
        // Find the sheet window
        for window in NSApp.windows {
            if window.isSheet {
                return window
            }
        }
        // Fallback: check main window's attached sheet
        if let mainWindow = NSApp.mainWindow,
           let sheetWindow = mainWindow.attachedSheet {
            return sheetWindow
        }
        return nil
    }
    
    private func moveWindow(by translation: CGSize) {
        guard let sheetWindow = findSheetWindow() else { return }
        
        // Store initial position on first drag
        if windowStartOrigin == nil {
            let frame = sheetWindow.frame
            windowStartOrigin = CGPoint(x: frame.origin.x, y: frame.origin.y)
        }
        
        guard let startOrigin = windowStartOrigin else { return }
        
        // Calculate new position
        var newOrigin = startOrigin
        newOrigin.x += translation.width
        newOrigin.y -= translation.height // Flip Y coordinate
        
        // Move the window
        sheetWindow.setFrameOrigin(NSPoint(x: newOrigin.x, y: newOrigin.y))
    }
}

// MARK: - Sheet Window Draggable Helper

struct SheetWindowDraggable: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = SheetDraggableView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Configure window when view updates
        if let window = nsView.window {
            window.isMovable = true
            window.isMovableByWindowBackground = true
        }
    }
}

class SheetDraggableView: NSView {
    private var dragStartPoint: NSPoint = .zero
    private var windowStartOrigin: NSPoint = .zero
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindow()
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if let window = newWindow {
            configureWindow(window: window)
        }
    }
    
    private func configureWindow(window: NSWindow? = nil) {
        let targetWindow = window ?? self.window
        guard let window = targetWindow else { return }
        
        window.isMovable = true
        window.isMovableByWindowBackground = true
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
    
    override func mouseDown(with event: NSEvent) {
        guard let window = window else { return }
        dragStartPoint = event.locationInWindow
        windowStartOrigin = window.frame.origin
    }
    
    override func mouseDragged(with event: NSEvent) {
        guard let window = window else { return }
        let currentPoint = event.locationInWindow
        let deltaX = currentPoint.x - dragStartPoint.x
        let deltaY = currentPoint.y - dragStartPoint.y
        
        var newOrigin = windowStartOrigin
        newOrigin.x += deltaX
        newOrigin.y += deltaY
        
        window.setFrameOrigin(newOrigin)
    }
}

struct DraggableHeaderView<Content: View>: View {
    let content: Content
    @State private var dragOffset: CGSize = .zero
    @State private var windowStartOrigin: CGPoint = .zero
    @State private var isDragging = false
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(.vertical, 4)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isDragging {
                            // Store initial window position
                            if let window = findSheetWindow() {
                                let frame = window.frame
                                windowStartOrigin = CGPoint(x: frame.origin.x, y: frame.origin.y)
                            }
                            isDragging = true
                        }
                        
                        // Move window based on drag
                        if let window = findSheetWindow() {
                            var newOrigin = windowStartOrigin
                            newOrigin.x += value.translation.width
                            newOrigin.y -= value.translation.height // Flip Y coordinate
                            window.setFrameOrigin(NSPoint(x: newOrigin.x, y: newOrigin.y))
                        }
                    }
                    .onEnded { _ in
                        isDragging = false
                        dragOffset = .zero
                    }
            )
    }
    
    private func findSheetWindow() -> NSWindow? {
        // Find the sheet window
        for window in NSApp.windows {
            if window.isSheet {
                return window
            }
        }
        // Fallback: check main window's attached sheet
        if let mainWindow = NSApp.mainWindow,
           let sheetWindow = mainWindow.attachedSheet {
            return sheetWindow
        }
        return nil
    }
}

// MARK: - Window Draggable Area

struct WindowDraggableArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = WindowDraggableNSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // No updates needed
    }
}

class WindowDraggableNSView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Make the window draggable
        if let window = window {
            window.isMovable = true
            window.isMovableByWindowBackground = true
        }
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return true
    }
    
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

// MARK: - Draggable Window Modifier

struct DraggableWindowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(DraggableWindowHelper())
            .onAppear {
                // Configure window after a short delay to ensure it's created
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    configureAllWindows()
                }
            }
    }
    
    private func configureAllWindows() {
        // Find and configure the sheet window
        for window in NSApp.windows {
            if window.isSheet {
                window.isMovable = true
                window.isMovableByWindowBackground = true
                // Also try to make the content view draggable
                if let contentView = window.contentView {
                    makeViewDraggable(contentView)
                }
            }
        }
        
        // Also check main window's attached sheet
        if let mainWindow = NSApp.mainWindow,
           let sheetWindow = mainWindow.attachedSheet {
            sheetWindow.isMovable = true
            sheetWindow.isMovableByWindowBackground = true
        }
    }
    
    private func makeViewDraggable(_ view: NSView) {
        // Recursively make all subviews support window dragging
        for subview in view.subviews {
            if subview is WindowDraggableNSView {
                // Already draggable
                continue
            }
            makeViewDraggable(subview)
        }
    }
}

struct DraggableWindowHelper: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = DraggableHelperView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Configure window when view updates
        if let window = nsView.window {
            window.isMovable = true
            window.isMovableByWindowBackground = true
            // Find the sheet window (it will be a child of the main window)
            if let parentWindow = NSApp.mainWindow,
               let sheetWindow = parentWindow.attachedSheet {
                sheetWindow.isMovable = true
                sheetWindow.isMovableByWindowBackground = true
            }
        }
    }
}

class DraggableHelperView: NSView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        configureWindow()
    }
    
    override func viewWillMove(toWindow newWindow: NSWindow?) {
        super.viewWillMove(toWindow: newWindow)
        if let window = newWindow {
            configureWindow(window: window)
        }
    }
    
    private func configureWindow(window: NSWindow? = nil) {
        let targetWindow = window ?? self.window
        guard let window = targetWindow else { return }
        
        window.isMovable = true
        window.isMovableByWindowBackground = true
        
        // Also try to find and configure the sheet window
        if let mainWindow = NSApp.mainWindow,
           let sheetWindow = mainWindow.attachedSheet {
            sheetWindow.isMovable = true
            sheetWindow.isMovableByWindowBackground = true
        }
        
        // Try all windows to find the sheet
        for win in NSApp.windows {
            if win.isSheet {
                win.isMovable = true
                win.isMovableByWindowBackground = true
            }
        }
    }
}
