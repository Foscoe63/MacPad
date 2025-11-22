import SwiftUI
@preconcurrency import ObjectiveC
import AppKit
import Foundation
@preconcurrency import Combine

// Detect if an attributed string contains any explicit foreground color attributes
private func mpAttributedHasExplicitForegroundColor(_ attributed: NSAttributedString) -> Bool {
    var found = false
    attributed.enumerateAttribute(.foregroundColor, in: NSRange(location: 0, length: attributed.length)) { value, _, stop in
        if value != nil { found = true; stop.pointee = true }
    }
    return found
}

// Detect a "hard" black color (non-dynamic) to correct in Dark mode
private func mpIsHardBlack(_ color: NSColor) -> Bool {
    // Convert to calibrated RGB space and compare components
    let rgb = color.usingColorSpace(.deviceRGB) ?? color.usingColorSpace(.sRGB) ?? color
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
    // Check for pure black or very dark colors (threshold for "black enough")
    return a > 0 && r < 0.1 && g < 0.1 && b < 0.1
}

// Check if we're in dark mode based on app theme preference
private func mpIsDarkMode() -> Bool {
    let theme = (UserDefaults.standard.string(forKey: "app.theme") ?? "system").lowercased()
    if theme == "dark" || theme == "highcontrast" {
        return true
    }
    if theme == "light" || theme == "sepia" {
        return false
    }
    // System theme - check actual system appearance
    if #available(macOS 10.14, *) {
        return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
    return false
}

// MARK: - NSViewRepresentable NSTextView with optional line number gutter (no NSRulerView)
struct CocoaTextView: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var lineSpacing: CGFloat
    var showLineNumbers: Bool
    var wordWrap: Bool = true
    var isRichText: Bool = false
    // Optional attributed content for initial/refresh display when in Rich mode
    var attributed: NSAttributedString? = nil
    var syntaxMode: SyntaxMode = .swift
    var lintingEnabled: Bool = true
    var goToDefinitionEnabled: Bool = true
    var linter: CodeLinter? = nil
    var onTextChange: ((String) -> Void)? = nil
    var onAttributedChange: ((NSAttributedString) -> Void)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = isRichText
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isEditable = true
        textView.isSelectable = true
        // For rich attributed content (RTF/HTML), disable adaptive color mapping ONLY if explicit colors exist to preserve
        // Otherwise keep adaptive mapping so dynamic system colors render correctly in Dark/Light modes.
        let hasExplicitFG = (attributed != nil) ? mpAttributedHasExplicitForegroundColor(attributed!) : false
        let shouldDisableAdaptive = isRichText && (attributed != nil) && hasExplicitFG
        textView.usesAdaptiveColorMappingForDarkAppearance = shouldDisableAdaptive ? false : true
        textView.usesFindBar = true
        textView.allowsUndo = true
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !wordWrap
        textView.autoresizingMask = [.width]
        if wordWrap {
            textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.containerSize.width = 0 // Force wrapping
        } else {
            textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.textContainer?.widthTracksTextView = false
        }
        textView.delegate = context.coordinator
        
        // Set up ⌘+click handling for Go to Definition
        // We'll handle this via a custom mouse event monitor in the coordinator
        if goToDefinitionEnabled {
            textView.isAutomaticLinkDetectionEnabled = false
        }

        // Text container formatting
        textView.textContainerInset = NSSize(width: 8, height: 8)
        applyTypography(textView, coordinator: context.coordinator)
        context.coordinator.baseInset = NSSize(width: 8, height: 8)

        // Initial content
        if isRichText, let attributed = attributed {
            textView.textStorage?.setAttributedString(attributed)
            context.coordinator.appliedInitialAttributed = true
            
            // Always check for hard black colors and replace them in dark mode
            let isDark = mpIsDarkMode()
            let fg = textView.textColor ?? NSColor.labelColor
            
            if let storage = textView.textStorage {
                storage.beginEditing()
                let fullRange = NSRange(location: 0, length: storage.length)
                
                // In dark mode, be aggressive: replace all black/dark colors with labelColor
                if isDark {
                    storage.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
                        if let color = value as? NSColor {
                            if mpIsHardBlack(color) {
                                storage.addAttribute(.foregroundColor, value: fg, range: range)
                            }
                        } else {
                            // No color set - apply labelColor
                            storage.addAttribute(.foregroundColor, value: fg, range: range)
                        }
                    }
                } else {
                    // Light mode: only apply if no colors exist
                    var hasColors = false
                    storage.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { _, _, _ in
                        hasColors = true
                    }
                    if !hasColors {
                        storage.addAttribute(.foregroundColor, value: fg, range: fullRange)
                    }
                }
                
                storage.endEditing()
            }
            
            // Set typing attributes
            var typing = textView.typingAttributes
            typing[.foregroundColor] = fg
            textView.typingAttributes = typing
        } else {
            textView.string = text
            // In Rich Text mode without pre-supplied attributed content, ensure typing uses dynamic label color
            if isRichText {
                let fg = textView.textColor ?? NSColor.labelColor
                var typing = textView.typingAttributes
                typing[.foregroundColor] = fg
                textView.typingAttributes = typing
                
                // Apply color to existing text
                if let storage = textView.textStorage {
                    storage.beginEditing()
                    storage.addAttribute(.foregroundColor, value: fg, range: NSRange(location: 0, length: storage.length))
                    storage.endEditing()
                }
            } else {
                // Plain text mode: ensure textColor is set but don't apply it globally
                // This allows syntax highlighting colors to show through
                textView.textColor = .labelColor
                
                // Apply syntax highlighting for plain text mode
                // Use async to ensure text storage is ready
                DispatchQueue.main.async {
                    if let storage = textView.textStorage, storage.length > 0 {
                        context.coordinator.applySyntaxHighlighting(to: storage, syntaxMode: syntaxMode)
                        context.coordinator.lastAppliedSyntaxMode = syntaxMode
                    }
                }
            }
        }

        // Wrap in scroll view
        let scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        // Use solid backgrounds themed by Preferences
        scrollView.drawsBackground = true
        let theme = (UserDefaults.standard.string(forKey: "app.theme") ?? "system").lowercased()
        if theme == "sepia" {
            scrollView.backgroundColor = NSColor(calibratedRed: 0.988, green: 0.972, blue: 0.938, alpha: 1.0)
            textView.drawsBackground = true
            textView.backgroundColor = NSColor(calibratedRed: 0.988, green: 0.972, blue: 0.938, alpha: 1.0)
            textView.textColor = .textColor
        } else if theme == "highcontrast" {
            scrollView.backgroundColor = NSColor(calibratedWhite: 0.06, alpha: 1.0)
            textView.drawsBackground = true
            textView.backgroundColor = NSColor(calibratedWhite: 0.06, alpha: 1.0)
            textView.textColor = NSColor(calibratedWhite: 0.92, alpha: 1.0)
        } else {
            scrollView.backgroundColor = .windowBackgroundColor
            textView.drawsBackground = true
            textView.backgroundColor = .textBackgroundColor
            textView.textColor = .labelColor
        }
        scrollView.documentView = textView

        // No NSRulerView usage; we draw a lightweight gutter view instead
        scrollView.hasVerticalRuler = false
        scrollView.rulersVisible = false
        scrollView.verticalRulerView = nil
        scrollView.hasHorizontalRuler = false

        // Make first responder when added
        DispatchQueue.main.async {
            textView.window?.makeFirstResponder(textView)
        }

        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView
        
        // Set up ⌘+click handling for Go to Definition using event monitoring
        if goToDefinitionEnabled {
            DispatchQueue.main.async {
                context.coordinator.setupGoToDefinitionMonitoring(for: textView)
            }
        }
        
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }
        // Prevent delegate feedback from mutating SwiftUI state during an update pass
        if context.coordinator.isUpdatingView { return }
        context.coordinator.isUpdatingView = true
        defer { context.coordinator.isUpdatingView = false }

        // Ensure adaptive color mapping matches current mode
        // Disable ONLY when rich and attributed content contains explicit colors to preserve them
        let hasExplicitFG = (attributed != nil) ? mpAttributedHasExplicitForegroundColor(attributed!) : false
        let shouldDisableAdaptive = isRichText && (attributed != nil) && hasExplicitFG
        textView.usesAdaptiveColorMappingForDarkAppearance = shouldDisableAdaptive ? false : true

        // Update string if external change
        // IMPORTANT: In Rich mode with attributed content, do NOT overwrite the text storage
        // with plain `string`, or you will lose colors and attributes.
        var stringWasUpdated = false
        if textView.string != text {
            let shouldOverwritePlain = !isRichText || (isRichText && attributed == nil)
            if shouldOverwritePlain {
                textView.string = text
                stringWasUpdated = true
            }
        }

        // Update word wrap setting
        let shouldWrap = wordWrap
        if textView.isHorizontallyResizable == shouldWrap {
            textView.isHorizontallyResizable = !shouldWrap
            if shouldWrap {
                textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
                textView.textContainer?.widthTracksTextView = true
                textView.textContainer?.containerSize.width = 0
            } else {
                textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
                textView.textContainer?.widthTracksTextView = false
            }
        }
        
        // Apply typography updates if changed
        applyTypography(textView, coordinator: context.coordinator)
        
        // Apply syntax highlighting if not in rich text mode
        // Apply after string update or when syntax mode might have changed
        // Do this LAST to ensure nothing overwrites it
        if !isRichText, let storage = textView.textStorage, storage.length > 0 {
            // Only reapply if string was updated or if we haven't applied highlighting yet
            if stringWasUpdated || context.coordinator.lastAppliedSyntaxMode != syntaxMode {
                // Use async with a small delay to ensure all other updates are done
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
                    guard let textView = context.coordinator.textView,
                          let storage = textView.textStorage,
                          storage.length > 0 else { return }
                    
                    // Double-check we're still in plain text mode
                    if !self.isRichText {
                        context.coordinator.applySyntaxHighlighting(to: storage, syntaxMode: syntaxMode)
                        context.coordinator.lastAppliedSyntaxMode = syntaxMode
                    }
                }
            }
        }

        // In Rich Text mode without supplied attributed content, ensure typing uses dynamic label color
        if isRichText && attributed == nil {
            let fg = textView.textColor ?? NSColor.labelColor
            var typing = textView.typingAttributes
            let isDark = mpIsDarkMode()
            
            typing[.foregroundColor] = fg
            textView.typingAttributes = typing
            
            // Apply color to all text
            if let storage = textView.textStorage {
                storage.beginEditing()
                let fullRange = NSRange(location: 0, length: storage.length)
                
                if isDark {
                    // In dark mode, replace all black/dark colors
                    storage.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
                        if let color = value as? NSColor {
                            if mpIsHardBlack(color) {
                                storage.addAttribute(.foregroundColor, value: fg, range: range)
                            }
                        } else {
                            storage.addAttribute(.foregroundColor, value: fg, range: range)
                        }
                    }
                } else {
                    // Light mode: apply to text without colors
                    storage.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
                        if value == nil {
                            storage.addAttribute(.foregroundColor, value: fg, range: range)
                        }
                    }
                }
                
                storage.endEditing()
            }
        }

        // Apply Rich vs Plain mode
        if textView.isRichText != isRichText {
            textView.isRichText = isRichText
            // Any mode switch resets our applied flag so we can re-evaluate content
            context.coordinator.appliedInitialAttributed = false
            if !isRichText {
                // Strip any existing attributes when switching to plain
                let plain = NSAttributedString(string: textView.string)
                textView.textStorage?.beginEditing()
                textView.textStorage?.setAttributedString(plain)
                textView.textStorage?.endEditing()
                // Ensure new typing is plain
                textView.typingAttributes = [:]
            } else {
                // Switched to Rich: if no attributed content supplied, make sure typing uses dynamic label color
                if attributed == nil {
                    let fg = textView.textColor ?? NSColor.labelColor
                    var typing = textView.typingAttributes
                    typing[.foregroundColor] = fg
                    textView.typingAttributes = typing
                    
                    // Apply color to all existing text
                    if let storage = textView.textStorage {
                        storage.beginEditing()
                        storage.addAttribute(.foregroundColor, value: fg, range: NSRange(location: 0, length: storage.length))
                        storage.endEditing()
                    }
                } else {
                    // When we have attributed content, check for hard black colors
                    let isDark = mpIsDarkMode()
                    let fg = textView.textColor ?? NSColor.labelColor
                    
                    if let storage = textView.textStorage {
                        storage.beginEditing()
                        let fullRange = NSRange(location: 0, length: storage.length)
                        
                        // In dark mode, be aggressive: replace all black/dark colors with labelColor
                        if isDark {
                            storage.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
                                if let color = value as? NSColor {
                                    if mpIsHardBlack(color) {
                                        storage.addAttribute(.foregroundColor, value: fg, range: range)
                                    }
                                } else {
                                    // No color set - apply labelColor
                                    storage.addAttribute(.foregroundColor, value: fg, range: range)
                                }
                            }
                        } else {
                            // Light mode: only apply if no colors exist
                            var hasColors = false
                            storage.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { _, _, _ in
                                hasColors = true
                            }
                            if !hasColors {
                                storage.addAttribute(.foregroundColor, value: fg, range: fullRange)
                            }
                        }
                        
                        storage.endEditing()
                    }
                    
                    // Set typing attributes
                    var typing = textView.typingAttributes
                    typing[.foregroundColor] = fg
                    textView.typingAttributes = typing
                }
            }
        }

        // In Rich mode: ensure text storage matches provided attributed content, re-apply when it doesn't
        if isRichText, let attributed = attributed {
            if let storage = textView.textStorage {
                let current = storage.attributedSubstring(from: NSRange(location: 0, length: storage.length))
                // Use NSObject equality to compare attributes too (not just string contents)
                let matches = current.isEqual(attributed)
                if !matches {
                    storage.beginEditing()
                    storage.setAttributedString(attributed)
                    storage.endEditing()
                    context.coordinator.appliedInitialAttributed = true
                }
            } else {
                textView.textStorage?.beginEditing()
                textView.textStorage?.setAttributedString(attributed)
                textView.textStorage?.endEditing()
                context.coordinator.appliedInitialAttributed = true
            }
            // Always check for hard black colors and replace them in dark mode
            let isDark = mpIsDarkMode()
            let fg = textView.textColor ?? NSColor.labelColor
            
            if let storage = textView.textStorage {
                storage.beginEditing()
                let fullRange = NSRange(location: 0, length: storage.length)
                
                // In dark mode, be aggressive: replace all black/dark colors with labelColor
                if isDark {
                    storage.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, range, _ in
                        if let color = value as? NSColor {
                            if mpIsHardBlack(color) {
                                storage.addAttribute(.foregroundColor, value: fg, range: range)
                            }
                        } else {
                            // No color set - apply labelColor
                            storage.addAttribute(.foregroundColor, value: fg, range: range)
                        }
                    }
                } else {
                    // Light mode: only apply if no colors exist
                    var hasColors = false
                    storage.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { _, _, _ in
                        hasColors = true
                    }
                    if !hasColors {
                        storage.addAttribute(.foregroundColor, value: fg, range: fullRange)
                    }
                }
                
                storage.endEditing()
            }
            
            // Set typing attributes
            var typing = textView.typingAttributes
            typing[.foregroundColor] = fg
            textView.typingAttributes = typing
        }

        // Ensure the editor remains first responder so typing works after updates (only if not already)
        DispatchQueue.main.async {
            if textView.window?.firstResponder !== textView {
                textView.window?.makeFirstResponder(textView)
            }
        }

        // Prepare scroll notifications for gutter redraw during scroll
        context.coordinator.scrollView = nsView
        context.coordinator.ensureScrollNotifications()

        // Line number gutter handling (no NSRulerView)
        let ensureGutter: () -> Void = {
            DispatchQueue.main.async {
                let clip = nsView.contentView
                // Ensure layout is ready before computing visible ranges
                if let lm = textView.layoutManager, let tc = textView.textContainer { lm.ensureLayout(for: tc) }

                if context.coordinator.gutterView == nil {
                    let gv = LineNumberGutterView(textView: textView, clipView: clip)
                    context.coordinator.gutterView = gv
                    nsView.contentView.addSubview(gv)
                }
                // Update gutter frame and inset
                let totalLines = textView.string.split(separator: "\n", omittingEmptySubsequences: false).count
                let width = LineNumberGutterView.desiredWidth(totalLines: totalLines, font: context.coordinator.gutterView?.numberFont ?? NSFont.monospacedSystemFont(ofSize: 10, weight: .regular))
                if context.coordinator.gutterWidth != width {
                    context.coordinator.gutterWidth = width
                }
                context.coordinator.layoutGutter()
                context.coordinator.updateTextInsets()
                context.coordinator.gutterView?.needsDisplay = true
            }
        }

        if showLineNumbers {
            if (nsView.window == nil) || nsView.bounds.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { ensureGutter() }
            } else {
                ensureGutter()
            }
        } else {
            // Remove gutter and reset insets
            context.coordinator.removeGutter()
            context.coordinator.updateTextInsets()
        }
    }

    private func applyTypography(_ textView: NSTextView, coordinator: Coordinator) {
        // Avoid redundant work and delegate churn
        let desiredFontSize = fontSize
        let desiredLineSpacing = lineSpacing
        if coordinator.lastAppliedFontSize == desiredFontSize && coordinator.lastAppliedLineSpacing == desiredLineSpacing {
            return
        }

        // IMPORTANT: In Rich mode when attributed content is present, do NOT override
        // imported fonts or paragraph styles (lists, indents, alignment, spacing, etc.).
        // Doing so will wipe HTML/RTF formatting. We only record the prefs to avoid
        // re-running this on every update.
        if isRichText, attributed != nil {
            coordinator.lastAppliedFontSize = desiredFontSize
            coordinator.lastAppliedLineSpacing = desiredLineSpacing
            return
        }

        // Plain text (or Rich without attributed snapshot): apply editor typography
        let font = NSFont.monospacedSystemFont(ofSize: desiredFontSize, weight: .regular)
        if textView.font != font {
            textView.font = font
        }
        if let textStorage = textView.textStorage {
            // Only apply line spacing; leave all other paragraph properties at defaults
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = max(0, desiredLineSpacing - 1) * font.pointSize * 0.5
            textStorage.beginEditing()
            textStorage.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: textStorage.length))
            textStorage.endEditing()
        }
        coordinator.lastAppliedFontSize = desiredFontSize
        coordinator.lastAppliedLineSpacing = desiredLineSpacing
    }

    // MARK: - Coordinator
    @MainActor
    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CocoaTextView
        weak var textView: NSTextView?
        weak var scrollView: NSScrollView?
        // Gutter management
        var gutterView: LineNumberGutterView?
        var gutterWidth: CGFloat = 44
        var baseInset: NSSize = NSSize(width: 8, height: 8)
        private var scrollNotificationsSetup = false
        // Track whether we've applied initial attributed content to avoid overriding user edits
        var appliedInitialAttributed = false
        // Reentrancy/feedback guards
        var isUpdatingView = false
        var lastAppliedFontSize: CGFloat?
        var lastAppliedLineSpacing: CGFloat?
        // Syntax highlighting
        var lastAppliedSyntaxMode: SyntaxMode?
        // Linting
        private var lintingObserver: AnyCancellable?
        private var appliedDiagnostics: Set<String> = []
        // Go to Definition event monitor
        private var goToDefinitionMonitor: Any?

        init(_ parent: CocoaTextView) {
            self.parent = parent
            super.init()
            
            // Observe linting diagnostics if linter is provided
            if let linter = parent.linter {
                lintingObserver = linter.$diagnostics
                    .receive(on: DispatchQueue.main)
                    .sink { [weak self] (diagnostics: [Diagnostic]) in
                        self?.applyLintingDiagnostics(diagnostics)
                    }
            }
            
            // Observe scroll-to-line notifications
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleScrollToLine(_:)),
                name: .mpScrollToLine,
                object: nil
            )
        }
        
        @objc private func handleScrollToLine(_ notification: Notification) {
            guard let textView = textView,
                  let userInfo = notification.userInfo,
                  let position = userInfo["position"] as? Int else { return }
            
            let range = NSRange(location: position, length: 0)
            textView.setSelectedRange(range)
            textView.scrollRangeToVisible(range)
            textView.showFindIndicator(for: range)
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
            // AnyCancellable automatically cancels when deallocated, so no explicit cancellation needed
            // Event monitors are automatically cleaned up when the app quits
            // We don't need to explicitly remove them in deinit due to Sendable constraints
        }
        
        func setupGoToDefinitionMonitoring(for textView: NSTextView) {
            guard parent.goToDefinitionEnabled else { return }
            
            goToDefinitionMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self, weak textView] event in
                guard let self = self,
                      let tv = textView,
                      event.modifierFlags.contains(.command),
                      self.parent.goToDefinitionEnabled,
                      !tv.string.isEmpty else {
                    return event
                }
                
                let location = tv.convert(event.locationInWindow, from: nil)
                let charIndex = tv.characterIndexForInsertion(at: location)
                let stringLength = (tv.string as NSString).length
                
                if charIndex >= 0 && charIndex < stringLength {
                    self.handleGoToDefinition(at: charIndex)
                    return nil // Consume the event to prevent normal mouse handling
                }
                
                return event
            }
        }

        func ensureScrollNotifications() {
            guard let clipView = scrollView?.contentView else { return }
            guard !scrollNotificationsSetup else { return }
            scrollNotificationsSetup = true
            clipView.postsBoundsChangedNotifications = true
            NotificationCenter.default.addObserver(self, selector: #selector(Coordinator.clipViewBoundsDidChange(_:)), name: NSView.boundsDidChangeNotification, object: clipView)
        }

        @objc private func clipViewBoundsDidChange(_ notification: Notification) {
            layoutGutter()
            gutterView?.needsDisplay = true
        }

        func layoutGutter() {
            guard let clip = scrollView?.contentView else { return }
            guard let gutterView = gutterView else { return }
            let clipBounds = clip.bounds
            let frame = NSRect(x: clipBounds.minX, y: clipBounds.minY, width: gutterWidth, height: clipBounds.height)
            if gutterView.frame != frame {
                gutterView.frame = frame
                gutterView.needsDisplay = true
            }
        }

        func updateTextInsets() {
            guard let tv = textView else { return }
            let newInset = NSSize(width: baseInset.width + (parent.showLineNumbers ? gutterWidth : 0), height: baseInset.height)
            if tv.textContainerInset != newInset {
                tv.textContainerInset = newInset
            }
        }

        func removeGutter() {
            gutterView?.removeFromSuperview()
            gutterView = nil
            gutterWidth = 44
        }
        
        // Apply syntax highlighting to text storage (only called in plain text mode)
        func applySyntaxHighlighting(to storage: NSTextStorage, syntaxMode: SyntaxMode) {
            guard storage.length > 0 else { 
                print("[SyntaxHighlight] Storage is empty")
                return 
            }
            
            let text = storage.string
            var appliedCount = 0
            let patterns = syntaxMode.syntaxPatterns
            
            print("[SyntaxHighlight] Applying highlighting for \(syntaxMode.displayName), text length: \(text.count), patterns: \(patterns.count)")
            print("[SyntaxHighlight] Sample text (first 100 chars): \(String(text.prefix(100)))")
            
            // Use a mutable copy to track which ranges have been colored
            var coloredRanges: Set<NSRange> = []
            
            storage.beginEditing()
            
            // Apply each syntax pattern
            // Process in order - later patterns can overwrite earlier ones if they overlap
            for (pattern, color) in patterns {
                // Convert SwiftUI Color to NSColor properly
                #if os(macOS)
                let nsColor = NSColor(color)
                #else
                let nsColor = UIColor(color)
                #endif
                var patternMatches = 0
                
                // Use Swift's regex API: matches is called on the String, not the Regex
                for match in text.matches(of: pattern) {
                    let range = match.range
                    let nsRange = NSRange(range, in: text)
                    if nsRange.location != NSNotFound && 
                       nsRange.location + nsRange.length <= storage.length {
                        // Use setAttributes to ensure it overrides any existing color
                        let attrs: [NSAttributedString.Key: Any] = [.foregroundColor: nsColor]
                        storage.setAttributes(attrs, range: nsRange)
                        coloredRanges.insert(nsRange)
                        appliedCount += 1
                        patternMatches += 1
                    }
                }
                
                if patternMatches > 0 {
                    print("[SyntaxHighlight] Pattern matched \(patternMatches) times, color: \(nsColor)")
                }
            }
            
            // Set default text color for any ranges that weren't colored
            let defaultColor = textView?.textColor ?? NSColor.labelColor
            let fullRange = NSRange(location: 0, length: storage.length)
            
            // Find ranges that don't have colors
            var currentPos = 0
            while currentPos < storage.length {
                var rangeHasColor = false
                let checkRange = NSRange(location: currentPos, length: 1)
                storage.enumerateAttribute(.foregroundColor, in: checkRange, options: []) { value, _, stop in
                    if value != nil {
                        rangeHasColor = true
                        stop.pointee = true
                    }
                }
                
                if !rangeHasColor {
                    // Find the extent of this uncolored range
                    var uncoloredLength = 1
                    while currentPos + uncoloredLength < storage.length {
                        let nextRange = NSRange(location: currentPos + uncoloredLength, length: 1)
                        var nextHasColor = false
                        storage.enumerateAttribute(.foregroundColor, in: nextRange, options: []) { value, _, stop in
                            if value != nil {
                                nextHasColor = true
                                stop.pointee = true
                            }
                        }
                        if nextHasColor {
                            break
                        }
                        uncoloredLength += 1
                    }
                    let uncoloredRange = NSRange(location: currentPos, length: uncoloredLength)
                    storage.addAttribute(.foregroundColor, value: defaultColor, range: uncoloredRange)
                    currentPos += uncoloredLength
                } else {
                    currentPos += 1
                }
            }
            
            storage.endEditing()
            
            // Force the text view to redraw
            textView?.needsDisplay = true
            
            // Verify colors were applied
            var verifiedCount = 0
            storage.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, _, _ in
                if value != nil {
                    verifiedCount += 1
                }
            }
            
            // Debug: print if we applied any colors
            print("[SyntaxHighlight] Total: Applied \(appliedCount) syntax color ranges, verified \(verifiedCount) total color ranges for \(syntaxMode.displayName)")
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = textView else { return }
            // Avoid mutating SwiftUI state if we're inside an update pass
            if isUpdatingView { return }
            let newText = tv.string
            if parent.text != newText {
                parent.text = newText
                parent.onTextChange?(newText)
            }
            // If rich text, also propagate attributed string so styles persist across tab switches
            if parent.isRichText, let storage = tv.textStorage {
                let range = NSRange(location: 0, length: storage.length)
                let snapshot = storage.attributedSubstring(from: range)
                parent.onAttributedChange?(snapshot)
            }
            if parent.showLineNumbers {
                let lines = newText.split(separator: "\n", omittingEmptySubsequences: false).count
                gutterWidth = LineNumberGutterView.desiredWidth(totalLines: lines, font: gutterView?.numberFont ?? NSFont.monospacedSystemFont(ofSize: 10, weight: .regular))
                updateTextInsets()
                gutterView?.needsDisplay = true
            }
            
            // Trigger linting if enabled
            if parent.lintingEnabled, let linter = parent.linter {
                linter.lint(newText, syntaxMode: parent.syntaxMode)
            }
            
            // Apply syntax highlighting if not in rich text mode
            // Always reapply on text change to keep highlighting up to date
            if !parent.isRichText, let storage = tv.textStorage, storage.length > 0 {
                applySyntaxHighlighting(to: storage, syntaxMode: parent.syntaxMode)
                lastAppliedSyntaxMode = parent.syntaxMode
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            gutterView?.needsDisplay = true
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            // Allow all edits for now
            return true
        }
        

        // Ensure typing attributes keep a dynamic foreground color in Rich Text when appropriate
        func textViewDidChangeTypingAttributes(_ notification: Notification) {
            guard let tv = textView else { return }
            // Only care in Rich Text mode
            guard parent.isRichText else { return }

            // Determine whether current content has explicit foreground colors
            var hasExplicitFG = false
            if let storage = tv.textStorage {
                let range = NSRange(location: 0, length: storage.length)
                let snapshot = storage.attributedSubstring(from: range)
                hasExplicitFG = mpAttributedHasExplicitForegroundColor(snapshot)
            }

            if hasExplicitFG {
                // Do not force a global typing color over imported colors
                if tv.typingAttributes[.foregroundColor] != nil {
                    var typing = tv.typingAttributes
                    typing.removeValue(forKey: .foregroundColor)
                    tv.typingAttributes = typing
                }
            } else {
                // Keep dynamic label color so text follows the theme; also correct hard black in Dark mode
                var typing = tv.typingAttributes
                let isDark = tv.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                let currentFG = typing[.foregroundColor] as? NSColor
                let desired = tv.textColor ?? NSColor.labelColor
                if currentFG == nil || (isDark && currentFG != nil && mpIsHardBlack(currentFG!)) {
                    typing[.foregroundColor] = desired
                    tv.typingAttributes = typing
                }
                // Keep the caret visible and matching theme (cosmetic)
                tv.insertionPointColor = desired
            }
        }
        
        // MARK: - Linting Diagnostics
        
        func applyLintingDiagnostics(_ diagnostics: [Diagnostic]) {
            guard let tv = textView, parent.lintingEnabled else { 
                print("[Linting] Skipped - linting disabled or no text view")
                return 
            }
            guard let storage = tv.textStorage, let layoutManager = tv.layoutManager, let _ = tv.textContainer else { 
                print("[Linting] Skipped - missing text storage or layout manager")
                return 
            }
            
            let storageLength = storage.length
            guard storageLength > 0 else { 
                print("[Linting] Skipped - empty storage")
                return 
            }
            
            print("[Linting] Applying \(diagnostics.count) diagnostics")
            
            // Remove old diagnostic underlines
            let fullRange = NSRange(location: 0, length: storageLength)
            storage.beginEditing()
            storage.removeAttribute(.underlineStyle, range: fullRange)
            storage.removeAttribute(.underlineColor, range: fullRange)
            appliedDiagnostics.removeAll()
            
            // Apply new diagnostics
            var appliedCount = 0
            for diagnostic in diagnostics {
                let lineRange = getLineRange(for: diagnostic.line, in: storage)
                guard lineRange.location != NSNotFound && lineRange.length > 0 else { 
                    print("[Linting] Could not find line \(diagnostic.line)")
                    continue 
                }
                
                // Calculate column position
                let lineStart = lineRange.location
                let columnOffset = min(max(0, diagnostic.column - 1), lineRange.length - 1)
                let diagnosticRange = NSRange(location: lineStart + columnOffset, length: 1)
                
                // Ensure range is valid
                guard diagnosticRange.location < storageLength && 
                      diagnosticRange.location + diagnosticRange.length <= storageLength else { 
                    print("[Linting] Invalid range for line \(diagnostic.line), column \(diagnostic.column)")
                    continue 
                }
                
                // Apply underline style based on severity
                let underlineStyle: NSUnderlineStyle
                let underlineColor: NSColor
                
                switch diagnostic.severity {
                case .error:
                    underlineStyle = .thick
                    underlineColor = .systemRed
                case .warning:
                    underlineStyle = .single
                    underlineColor = .systemOrange
                case .hint:
                    underlineStyle = .patternDot
                    underlineColor = .systemBlue
                }
                
                // Extend underline to end of word/line for better visibility
                var finalRange = diagnosticRange
                if diagnosticRange.length == 1 {
                    let nsString = storage.string as NSString
                    let extendedRange = nsString.rangeOfWord(at: diagnosticRange.location)
                    if extendedRange.location != NSNotFound && extendedRange.length > 1 {
                        finalRange = extendedRange
                    } else {
                        // If no word found, underline the whole line
                        finalRange = NSRange(location: lineStart, length: lineRange.length)
                    }
                }
                
                // Ensure final range is valid
                if finalRange.location < storageLength && 
                   finalRange.location + finalRange.length <= storageLength {
                    storage.addAttribute(.underlineStyle, value: underlineStyle.rawValue, range: finalRange)
                    storage.addAttribute(.underlineColor, value: underlineColor, range: finalRange)
                    appliedCount += 1
                    print("[Linting] Applied \(diagnostic.severity) underline at line \(diagnostic.line): \(diagnostic.message)")
                }
                
                appliedDiagnostics.insert("\(diagnostic.line):\(diagnostic.column)")
            }
            storage.endEditing()
            
            // Invalidate layout to show underlines
            layoutManager.invalidateDisplay(forCharacterRange: fullRange)
            tv.needsDisplay = true
            
            print("[Linting] Applied \(appliedCount) diagnostic underlines")
        }
        
        private func getLineRange(for lineNumber: Int, in storage: NSTextStorage) -> NSRange {
            let string = storage.string as NSString
            guard lineNumber > 0, string.length > 0 else {
                return NSRange(location: NSNotFound, length: 0)
            }
            
            // Use the same line counting method as CodeLinter: components(separatedBy: .newlines)
            // This ensures line numbers match exactly
            let lines = string.components(separatedBy: .newlines)
            guard lineNumber <= lines.count else {
                print("[Linting] getLineRange: Line \(lineNumber) out of range (total lines: \(lines.count))")
                return NSRange(location: NSNotFound, length: 0)
            }
            
            // Calculate the range for the requested line by finding line boundaries
            var currentLocation = 0
            for (index, line) in lines.enumerated() {
                let lineIndex = index + 1 // 1-based line numbers
                
                if lineIndex == lineNumber {
                    // Found the line - return its range (without trailing newline)
                    let lineLength = (line as NSString).length
                    return NSRange(location: currentLocation, length: lineLength)
                }
                
                // Move to next line: current line + newline character(s)
                let lineLength = (line as NSString).length
                currentLocation += lineLength
                
                // Add newline length (check actual string content)
                if index < lines.count - 1 && currentLocation < string.length {
                    let nextChar = string.substring(with: NSRange(location: currentLocation, length: min(2, string.length - currentLocation)))
                    if nextChar.hasPrefix("\r\n") {
                        currentLocation += 2
                    } else if nextChar.hasPrefix("\n") || nextChar.hasPrefix("\r") {
                        currentLocation += 1
                    }
                }
            }
            
            // Should not reach here, but return not found if we do
            print("[Linting] getLineRange: Could not find line \(lineNumber) (total lines: \(lines.count))")
            return NSRange(location: NSNotFound, length: 0)
        }
        
        // MARK: - Go to Definition
        
        func handleGoToDefinition(at charIndex: Int) {
            guard let tv = textView, let storage = tv.textStorage else { return }
            
            let string = storage.string as NSString
            guard charIndex >= 0 && charIndex < string.length else { return }
            
            let range = string.rangeOfWord(at: charIndex)
            guard range.location != NSNotFound && range.length > 0 else { return }
            
            let word = string.substring(with: range)
            
            // Find definition (simple implementation - looks for function/class/struct definitions)
            let searchString = string as String
            let lines = searchString.components(separatedBy: .newlines)
            
            // Look for definition patterns
            var foundLine: Int?
            for (index, line) in lines.enumerated() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                
                // Swift: func, class, struct, enum, var, let
                if trimmed.contains("func \(word)") || 
                   trimmed.contains("class \(word)") ||
                   trimmed.contains("struct \(word)") ||
                   trimmed.contains("enum \(word)") ||
                   trimmed.contains("var \(word)") ||
                   trimmed.contains("let \(word)") {
                    foundLine = index + 1
                    break
                }
                
                // Python: def, class
                if trimmed.contains("def \(word)") ||
                   trimmed.contains("class \(word)") {
                    foundLine = index + 1
                    break
                }
                
                // JavaScript: function, class, const, let, var
                if trimmed.contains("function \(word)") ||
                   trimmed.contains("class \(word)") ||
                   trimmed.contains("const \(word)") ||
                   trimmed.contains("let \(word)") ||
                   trimmed.contains("var \(word)") {
                    foundLine = index + 1
                    break
                }
            }
            
            if let targetLine = foundLine {
                // Scroll to definition
                let lineRange = getLineRange(for: targetLine, in: storage)
                if lineRange.location != NSNotFound {
                    tv.scrollRangeToVisible(lineRange)
                    tv.setSelectedRange(NSRange(location: lineRange.location, length: 0))
                    tv.showFindIndicator(for: lineRange)
                }
            } else {
                // Show alert if definition not found
                let alert = NSAlert()
                alert.messageText = "Definition not found"
                alert.informativeText = "Could not find definition for '\(word)'"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }
}

// MARK: - NSString Extension for Word Range

extension NSString {
    func rangeOfWord(at location: Int) -> NSRange {
        guard location >= 0 && location < length else {
            return NSRange(location: NSNotFound, length: 0)
        }
        
        var start = location
        var end = location
        
        let alphanumerics = CharacterSet.alphanumerics
        let underscore = CharacterSet(charactersIn: "_")
        let wordChars = alphanumerics.union(underscore)
        
        // Find word start
        while start > 0 {
            let char = character(at: start - 1)
            if let scalar = UnicodeScalar(char), wordChars.contains(scalar) {
                start -= 1
            } else {
                break
            }
        }
        
        // Find word end
        while end < length {
            let char = character(at: end)
            if let scalar = UnicodeScalar(char), wordChars.contains(scalar) {
                end += 1
            } else {
                break
            }
        }
        
        return NSRange(location: start, length: end - start)
    }
}


// MARK: - Line number gutter view (no NSRulerView)
@MainActor
final class LineNumberGutterView: NSView {
    weak var textView: NSTextView?
    weak var clipView: NSClipView?

    let numberFont: NSFont = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
    let gutterBackground = NSColor.textBackgroundColor
    let lineNumberColor = NSColor.secondaryLabelColor
    let separatorColor = NSColor.separatorColor.withAlphaComponent(0.25)
    let padding: CGFloat = 6

    init(textView: NSTextView, clipView: NSClipView) {
        self.textView = textView
        self.clipView = clipView
        super.init(frame: .zero)
        // Draw synchronously on the main thread to avoid hitting system icon rendering paths
        // that may rely on Metal shaders during concurrent/layer-backed drawing.
        // Keep the view non-layer-backed and single-threaded for stability.
        wantsLayer = false
        // canDrawConcurrently defaults to false; leave it disabled for safety.
        // initial size will be set by Coordinator.layoutGutter()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // Ensure the gutter never intercepts input; all events go to the NSTextView
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override var acceptsFirstResponder: Bool { false }

    static func desiredWidth(totalLines: Int, font: NSFont) -> CGFloat {
        let safeTotal = max(1, totalLines)
        let digits = max(2, Int(ceil(log10(Double(safeTotal + 1)))))
        return CGFloat(8 + digits * 8) + 12 // approximate matching previous padding
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else { return }

        // Background
        gutterBackground.setFill()
        bounds.fill()

        // Separator
        separatorColor.setStroke()
        let sepPath = NSBezierPath()
        sepPath.move(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.minY))
        sepPath.line(to: NSPoint(x: bounds.maxX - 0.5, y: bounds.maxY))
        sepPath.lineWidth = 1
        sepPath.stroke()

        // Attributes
        let attrs: [NSAttributedString.Key: Any] = [
            .font: numberFont,
            .foregroundColor: lineNumberColor
        ]

        // Visible range (compute using textView.visibleRect in text-container coords)
        let visibleInTextView = textView.visibleRect
        let rectInContainer = NSRect(
            x: visibleInTextView.origin.x - textView.textContainerOrigin.x,
            y: visibleInTextView.origin.y - textView.textContainerOrigin.y,
            width: visibleInTextView.size.width,
            height: visibleInTextView.size.height
        )
        let glyphRange = layoutManager.glyphRange(forBoundingRect: rectInContainer, in: textContainer)

        // If the document is empty, draw line 1 near the top of the visible area
        if glyphRange.length == 0 {
            let numberString = "1" as NSString
            let size = numberString.size(withAttributes: attrs)
            let x = self.bounds.maxX - self.padding - size.width - 2
            let lineHeight = layoutManager.defaultLineHeight(for: textView.font ?? numberFont)
            // Place at the top of the gutter minus one line height (so it appears at the first line)
            let y = self.bounds.maxY - lineHeight
            numberString.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
            return
        }

        var lastLineNumberDrawn: Int? = nil

        layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { (_, usedRect, _, glyphRange, _) in
            let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            let nsString = textView.string as NSString
            let substring = nsString.substring(to: charRange.location) as NSString
            let lineNumber = substring.components(separatedBy: "\n").count

            // Draw line number only if not already drawn for this line (skip wrapped fragments)
            if lineNumber != lastLineNumberDrawn {
                lastLineNumberDrawn = lineNumber

                // Convert fragment rect from text-container coords to textView, then to gutter coords
                var rectInTextView = usedRect
                rectInTextView.origin.x += textView.textContainerOrigin.x
                rectInTextView.origin.y += textView.textContainerOrigin.y
                let rectInGutter = self.convert(rectInTextView, from: textView)

                let numberString = "\(lineNumber)" as NSString
                let size = numberString.size(withAttributes: attrs)
                let x = self.bounds.maxX - self.padding - size.width - 2
                // Draw near the top of the line fragment so numbering increases downwards
                let y = rectInGutter.maxY - size.height - 1
                numberString.draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
            }
        }
    }
}
