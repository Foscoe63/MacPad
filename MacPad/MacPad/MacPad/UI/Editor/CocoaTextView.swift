import AppKit
@preconcurrency import Combine
import Foundation
@preconcurrency import ObjectiveC
import SwiftUI

// Detect if an attributed string contains any explicit foreground color attributes
private func mpAttributedHasExplicitForegroundColor(_ attributed: NSAttributedString) -> Bool {
  var found = false
  attributed.enumerateAttribute(
    .foregroundColor, in: NSRange(location: 0, length: attributed.length)
  ) { value, _, stop in
    if value != nil {
      found = true
      stop.pointee = true
    }
  }
  return found
}

// Detect a "hard" black color (non-dynamic) to correct in Dark mode
private func mpIsHardBlack(_ color: NSColor) -> Bool {
  // Convert to calibrated RGB space and compare components
  let rgb = color.usingColorSpace(.deviceRGB) ?? color.usingColorSpace(.sRGB) ?? color
  var r: CGFloat = 0
  var g: CGFloat = 0
  var b: CGFloat = 0
  var a: CGFloat = 0
  rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
  // Check for pure black or very dark colors (threshold for "black enough")
  return a > 0 && r < 0.1 && g < 0.1 && b < 0.1
}

// Check if we're in dark mode based on system appearance
private func mpIsDarkMode() -> Bool {
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
  var fileExtension: String? = nil  // For custom syntax mode detection
  var lintingEnabled: Bool = true
  var goToDefinitionEnabled: Bool = true
  var linter: CodeLinter? = nil
  var onTextChange: ((String) -> Void)? = nil
  var onAttributedChange: ((NSAttributedString) -> Void)? = nil
  var onCursorChange: ((Int, Int, Int) -> Void)? = nil  // line, column, position

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let textView = MacPadTextView()
    textView.isRichText = isRichText
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.isAutomaticDashSubstitutionEnabled = false
    textView.isAutomaticTextReplacementEnabled = false
    textView.isAutomaticSpellingCorrectionEnabled = false
    textView.isAutomaticDataDetectionEnabled = false
    textView.isAutomaticLinkDetectionEnabled = false
    textView.enabledTextCheckingTypes = 0
    textView.isEditable = true
    textView.isSelectable = true
    // Configure adaptive color mapping
    // For plain text mode, we'll use adaptive mapping AND manually set colors
    // For rich text mode, disable ONLY when attributed content contains explicit colors to preserve
    if !isRichText {
      // Plain text mode: enable adaptive mapping AND set explicit colors
      textView.usesAdaptiveColorMappingForDarkAppearance = true
      // Set colors immediately
      textView.textColor = NSColor.textColor
      textView.backgroundColor = NSColor.textBackgroundColor
    } else {
      // Rich text mode: disable adaptive mapping to ensure user colors are respected
      // We handle default colors manually
      textView.usesAdaptiveColorMappingForDarkAppearance = false
    }
    textView.usesFindBar = true
    textView.allowsUndo = true
    textView.isVerticallyResizable = true
    textView.isHorizontallyResizable = !wordWrap
    textView.autoresizingMask = [.width]
    if wordWrap {
      textView.textContainer?.containerSize = NSSize(
        width: 0, height: CGFloat.greatestFiniteMagnitude)
      textView.textContainer?.widthTracksTextView = true
      textView.textContainer?.containerSize.width = 0  // Force wrapping
    } else {
      textView.textContainer?.containerSize = NSSize(
        width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
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

    // CRITICAL: Set text color for plain text mode using explicit colors
    // Use white text on dark background in dark mode, black on white in light mode
    if !isRichText {
      let isDark = mpIsDarkMode()
      let fg = isDark ? NSColor.white : NSColor.black
      let bg = isDark ? NSColor(white: 0.1, alpha: 1.0) : NSColor.white
      textView.textColor = fg
      textView.backgroundColor = bg
      // textView.appearance = NSApp.effectiveAppearance
      // Set typing attributes immediately so new text gets the right color
      var typing = textView.typingAttributes
      typing[.foregroundColor] = fg
      textView.typingAttributes = typing
    }

    applyTypography(textView, coordinator: context.coordinator)
    context.coordinator.baseInset = NSSize(width: 8, height: 8)

    // Initial content
    if isRichText, let attributed = attributed {
      textView.textStorage?.setAttributedString(attributed)
      context.coordinator.appliedInitialAttributed = true
      context.coordinator.lastAssignedAttributed = attributed

      // CRITICAL: In rich text mode, replace ALL colors in dark mode to ensure visibility
      let isDark = mpIsDarkMode()
      // Use explicit white in dark mode, black in light mode (not labelColor which might be wrong)
      let fg = isDark ? NSColor.white : NSColor.black
      let bg = isDark ? NSColor(white: 0.1, alpha: 1.0) : NSColor.white

      // Set background color
      textView.backgroundColor = bg
      // textView.appearance = NSApp.effectiveAppearance

      if let storage = textView.textStorage {
        storage.beginEditing()
        let fullRange = NSRange(location: 0, length: storage.length)

        // Only replace hard black colors and apply to uncolored text
        // This preserves user-selected colors (though in initial setup, we may not have any yet)
        storage.enumerateAttribute(.foregroundColor, in: fullRange, options: []) {
          value, range, _ in
          if let color = value as? NSColor {
            // Only replace hard black colors, preserve all other colors (including user-selected)
            if mpIsHardBlack(color) {
              storage.removeAttribute(.foregroundColor, range: range)
              storage.addAttribute(.foregroundColor, value: fg, range: range)
            }
            // Otherwise, keep the existing color (user-selected colors are preserved)
          } else {
            // No color set - apply default color
            storage.addAttribute(.foregroundColor, value: fg, range: range)
          }
        }
        // Also handle any ranges that don't have a color attribute at all
        var currentPos = 0
        while currentPos < storage.length {
          var rangeHasColor = false
          let checkRange = NSRange(location: currentPos, length: 1)
          storage.enumerateAttribute(.foregroundColor, in: checkRange, options: []) {
            value, _, stop in
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
              storage.enumerateAttribute(.foregroundColor, in: nextRange, options: []) {
                value, _, stop in
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
            storage.addAttribute(.foregroundColor, value: fg, range: uncoloredRange)
            currentPos += uncoloredLength
          } else {
            currentPos += 1
          }
        }

        storage.endEditing()
      }

      // Set typing attributes
      var typing = textView.typingAttributes
      typing[.foregroundColor] = fg
      textView.typingAttributes = typing
      // CRITICAL: Do not set textColor for rich text as it overwrites attributes
      // textView.textColor = fg
    } else {
      textView.string = text
      // In Rich Text mode without pre-supplied attributed content, use explicit colors
      if isRichText {
        let isDark = mpIsDarkMode()
        let fg = isDark ? NSColor.white : NSColor.black
        let bg = isDark ? NSColor(white: 0.1, alpha: 1.0) : NSColor.white

        textView.textColor = fg
        textView.backgroundColor = bg
        // textView.appearance = NSApp.effectiveAppearance

        var typing = textView.typingAttributes
        typing[.foregroundColor] = fg
        textView.typingAttributes = typing

        // Apply color to existing text - only replace hard black colors
        // This preserves user-selected colors
        if let storage = textView.textStorage, storage.length > 0 {
          storage.beginEditing()
          let fullRange = NSRange(location: 0, length: storage.length)
          // Only replace hard black colors and apply to uncolored text
          // This preserves user-selected colors
          storage.enumerateAttribute(.foregroundColor, in: fullRange, options: []) {
            value, range, _ in
            if let color = value as? NSColor {
              // Only replace hard black colors, preserve all other colors (including user-selected)
              if mpIsHardBlack(color) {
                storage.removeAttribute(.foregroundColor, range: range)
                storage.addAttribute(.foregroundColor, value: fg, range: range)
              }
              // Otherwise, keep the existing color (user-selected colors are preserved)
            } else {
              // No color set - apply default color
              storage.addAttribute(.foregroundColor, value: fg, range: range)
            }
          }
          // Also handle any ranges that don't have a color attribute at all
          var currentPos = 0
          while currentPos < storage.length {
            var rangeHasColor = false
            let checkRange = NSRange(location: currentPos, length: 1)
            storage.enumerateAttribute(.foregroundColor, in: checkRange, options: []) {
              value, _, stop in
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
                storage.enumerateAttribute(.foregroundColor, in: nextRange, options: []) {
                  value, _, stop in
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
              storage.addAttribute(.foregroundColor, value: fg, range: uncoloredRange)
              currentPos += uncoloredLength
            } else {
              currentPos += 1
            }
          }
          storage.endEditing()
        }
      } else {
        // Plain text mode: completely rebuild text storage with correct colors
        // This ensures no black colors are left behind
        let isDark = mpIsDarkMode()
        // Use explicit colors that we know work
        let fg = isDark ? NSColor.white : NSColor.black
        // CRITICAL: Use a dark background in dark mode, light in light mode
        let bg = isDark ? NSColor(white: 0.1, alpha: 1.0) : NSColor.white

        // CRITICAL: Set colors BEFORE setting string
        textView.textColor = fg
        textView.backgroundColor = bg
        // Ensure the text view uses the correct appearance
        // textView.appearance = NSApp.effectiveAppearance

        // Set typing attributes so new text gets the right color
        var typing = textView.typingAttributes
        typing[.foregroundColor] = fg
        textView.typingAttributes = typing

        // Set the string
        textView.string = text

        // CRITICAL: Completely rebuild the text storage with a fresh attributed string
        // This ensures no old color attributes remain
        if let storage = textView.textStorage {
          // Create a completely new attributed string with ONLY the correct color
          let attributedText = NSMutableAttributedString(string: text)
          let fullRange = NSRange(location: 0, length: attributedText.length)

          // Set ONLY the foreground color - no other attributes
          attributedText.addAttribute(.foregroundColor, value: fg, range: fullRange)

          // Debug: print what color we're using
          print("[CocoaTextView] Setting text color in \(isDark ? "DARK" : "LIGHT") mode: \(fg)")
          print("[CocoaTextView] Background color: \(bg)")
          print("[CocoaTextView] textView.textColor: \(textView.textColor?.description ?? "nil")")

          // Replace the entire text storage - this should remove ALL old attributes
          storage.beginEditing()
          storage.setAttributedString(attributedText)
          storage.endEditing()

          // Verify the color was set
          if storage.length > 0 {
            if let actualColor = storage.attribute(.foregroundColor, at: 0, effectiveRange: nil)
              as? NSColor
            {
              print("[CocoaTextView] Actual color in storage: \(actualColor)")
            }
          }

          // Force a redraw
          textView.needsDisplay = true
          textView.needsLayout = true
        }

        // Apply syntax highlighting for plain text mode
        // Use async to ensure text storage is ready, but AFTER we've set the base color
        DispatchQueue.main.async {
          // Ensure textColor is still set correctly before applying syntax highlighting
          let isDark = mpIsDarkMode()
          let fg = isDark ? NSColor.white : NSColor.black
          let bg = isDark ? NSColor(white: 0.1, alpha: 1.0) : NSColor.white
          if textView.textColor != fg {
            textView.textColor = fg
          }
          textView.backgroundColor = bg
          // textView.appearance = NSApp.effectiveAppearance

          if let storage = textView.textStorage, storage.length > 0 {
            // Ensure base color is applied before syntax highlighting
            storage.beginEditing()
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.removeAttribute(.foregroundColor, range: fullRange)
            storage.addAttribute(.foregroundColor, value: fg, range: fullRange)
            storage.endEditing()

            // Now apply syntax highlighting (it will use the correct default color)
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
    scrollView.drawsBackground = true
    textView.drawsBackground = true

    // CRITICAL: Set background color for dark mode visibility
    // Both scroll view and text view need dark backgrounds in dark mode
    let isDark = mpIsDarkMode()
    let bg = isDark ? NSColor(white: 0.1, alpha: 1.0) : NSColor.white
    scrollView.backgroundColor = bg
    textView.backgroundColor = bg
    // textView.appearance = NSApp.effectiveAppearance

    scrollView.documentView = textView

    // Set coordinator properties
    context.coordinator.textView = textView
    context.coordinator.scrollView = scrollView

    // No NSRulerView usage; we draw a lightweight gutter view instead
    scrollView.hasVerticalRuler = false
    scrollView.rulersVisible = false
    scrollView.verticalRulerView = nil
    scrollView.hasHorizontalRuler = false

    // Don't force first responder - let the user click to focus naturally
    // This prevents interference with cursor movement and selection

    // Set up ⌘+click handling for Go to Definition using event monitoring
    if goToDefinitionEnabled {
      DispatchQueue.main.async {
        context.coordinator.setupGoToDefinitionMonitoring(for: textView)
      }
    }

    // Set up mouse tracking to detect when user is dragging to select
    DispatchQueue.main.async {
      context.coordinator.setupMouseTracking(for: textView)
    }

    return scrollView
  }

  func updateNSView(_ nsView: NSScrollView, context: Context) {
    guard let textView = context.coordinator.textView else { return }
    // Prevent delegate feedback from mutating SwiftUI state during an update pass
    if context.coordinator.isUpdatingView { return }
    context.coordinator.isUpdatingView = true
    defer {
      context.coordinator.isUpdatingView = false
      // CRITICAL: Always ensure text view remains selectable after any update
      // This is essential for selection to work after editing
      if !textView.isSelectable {
        textView.isSelectable = true
      }
      if !textView.isEditable {
        textView.isEditable = true
      }
    }

    // Configure adaptive color mapping
    // For rich text mode, disable adaptive mapping and use explicit colors
    if isRichText {
      textView.usesAdaptiveColorMappingForDarkAppearance = false
      // Set explicit colors for rich text mode
      let isDark = mpIsDarkMode()
      // let fg = isDark ? NSColor.white : NSColor.black // Unused
      let bg = isDark ? NSColor(white: 0.1, alpha: 1.0) : NSColor.white
      // CRITICAL: Do NOT set textColor here for Rich Text, as it overrides user selection
      // textView.textColor = fg
      textView.backgroundColor = bg
      // textView.appearance = NSApp.effectiveAppearance
      nsView.backgroundColor = bg
    } else {
      // Plain text mode: use explicit colors for dark/light mode
      textView.usesAdaptiveColorMappingForDarkAppearance = false
      // Use explicit colors that we know work
      let isDark = mpIsDarkMode()
      let fg = isDark ? NSColor.white : NSColor.black
      let bg = isDark ? NSColor(white: 0.1, alpha: 1.0) : NSColor.white
      textView.textColor = fg
      textView.backgroundColor = bg
      // textView.appearance = NSApp.effectiveAppearance
      // Also set scroll view background to match
      nsView.backgroundColor = bg
    }

    // Update string if external change
    // IMPORTANT: In Rich mode with attributed content, do NOT overwrite the text storage
    // with plain `string`, or you will lose colors and attributes.
    // CRITICAL: Only update string if it's an external change (not from user typing)
    // Never overwrite the text view's string if:
    // 1. We're processing a text change from the text view (user is typing)
    // 2. The text view is first responder (user is actively using it)
    // 3. There's any selection (user might be selecting/copying)
    if textView.string != text && !context.coordinator.isProcessingTextChange {
      let shouldOverwritePlain = !isRichText || (isRichText && attributed == nil)
      if shouldOverwritePlain {
        let isFirstResponder = textView.window?.firstResponder === textView
        let hasSelection = textView.selectedRange().length > 0
        // Be very conservative - only update if it's clearly an external change
        // and the user is not actively interacting with the text view
        if !isFirstResponder && !hasSelection && !context.coordinator.isMouseDown {
          // CRITICAL: Set textColor BEFORE setting string for plain text mode
          if !isRichText {
            let isDark = mpIsDarkMode()
            let fg = isDark ? NSColor.white : NSColor.black
            let bg = isDark ? NSColor(white: 0.1, alpha: 1.0) : NSColor.white
            textView.textColor = fg
            textView.backgroundColor = bg
            // textView.appearance = NSApp.effectiveAppearance
          }

          textView.string = text

          // Ensure plain text mode uses explicit colors for visibility
          if !isRichText {
            let isDark = mpIsDarkMode()
            let fg = isDark ? NSColor.white : NSColor.black
            let bg = isDark ? NSColor(white: 0.1, alpha: 1.0) : NSColor.white
            // Ensure textColor is still set (setting string might reset it)
            textView.textColor = fg
            textView.backgroundColor = bg
            // textView.appearance = NSApp.effectiveAppearance

            // Set typing attributes
            var typing = textView.typingAttributes
            typing[.foregroundColor] = fg
            textView.typingAttributes = typing

            // Apply color to text storage - completely rebuild to remove ALL old attributes
            if let storage = textView.textStorage, storage.length > 0 {
              let savedSelection = textView.selectedRange()

              // Create a completely fresh attributed string with ONLY the correct color
              let isDark = mpIsDarkMode()
              let fg = isDark ? NSColor.white : NSColor.black
              let attributedText = NSMutableAttributedString(string: textView.string)
              let fullRange = NSRange(location: 0, length: attributedText.length)
              attributedText.addAttribute(.foregroundColor, value: fg, range: fullRange)

              // Replace entire storage - this removes ALL old attributes
              storage.beginEditing()
              storage.setAttributedString(attributedText)
              storage.endEditing()

              // Restore selection if it was valid
              if savedSelection.location <= storage.length {
                textView.setSelectedRange(savedSelection)
              }
            }
          }
        }
      }
    }

    // Update word wrap setting
    let shouldWrap = wordWrap
    if textView.isHorizontallyResizable == shouldWrap {
      textView.isHorizontallyResizable = !shouldWrap
      if shouldWrap {
        textView.textContainer?.containerSize = NSSize(
          width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize.width = 0
      } else {
        textView.textContainer?.containerSize = NSSize(
          width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
      }
    }

    // CRITICAL: Only apply typography updates if user is NOT actively typing
    // Modifying text storage attributes resets cursor position and clears selection
    let isFirstResponder = textView.window?.firstResponder === textView
    let hasSelection = textView.selectedRange().length > 0
    if !isFirstResponder && !hasSelection && !context.coordinator.isProcessingTextChange
      && !context.coordinator.isMouseDown
    {
      applyTypography(textView, coordinator: context.coordinator)
    }

    // TEMPORARILY DISABLED: Apply syntax highlighting if not in rich text mode
    // Syntax highlighting is disabled to fix cursor movement and selection issues
    // TODO: Re-enable with a better implementation that doesn't interfere with user input
    /*
    if !isRichText, let storage = textView.textStorage, storage.length > 0 {
        // Only reapply if string was updated or if we haven't applied highlighting yet
        if stringWasUpdated || context.coordinator.lastAppliedSyntaxMode != syntaxMode {
            // Mark that we need highlighting update
            context.coordinator.needsHighlightingUpdate = true
            // Try to apply immediately - will skip if selection exists
            context.coordinator.applySyntaxHighlighting(to: storage, syntaxMode: syntaxMode)
            context.coordinator.lastAppliedSyntaxMode = syntaxMode
        }
    }
    */

    // In Rich Text mode without supplied attributed content, use explicit colors
    // CRITICAL: Only set default colors for typing attributes, don't modify existing text storage
    // This preserves user-selected colors and prevents overriding colors the user has chosen
    if isRichText && attributed == nil {
      let isDark = mpIsDarkMode()
      let fg = isDark ? NSColor.white : NSColor.black
      let bg = isDark ? NSColor(white: 0.1, alpha: 1.0) : NSColor.white

      // Always set textColor and background (these are defaults, not applied to existing text)
      // CRITICAL: Do NOT set textColor here for Rich Text, as it overrides user selection
      // textView.textColor = fg
      textView.backgroundColor = bg
      // textView.appearance = NSApp.effectiveAppearance

      // Set typing attributes so new text gets the right color
      // But don't modify existing text storage - that would override user-selected colors
      // CRITICAL: Only set default typing attributes if none are set, to avoid overriding user selection
      var typing = textView.typingAttributes
      if typing[.foregroundColor] == nil {
        typing[.foregroundColor] = fg
        textView.typingAttributes = typing
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
        // Switched to Rich: use explicit colors for dark/light mode
        let isDark = mpIsDarkMode()
        let fg = isDark ? NSColor.white : NSColor.black
        let bg = isDark ? NSColor(white: 0.1, alpha: 1.0) : NSColor.white

        // textView.textColor = fg
        textView.backgroundColor = bg
        // textView.appearance = NSApp.effectiveAppearance

        if attributed == nil {
          // No attributed content: apply explicit color to all text
          var typing = textView.typingAttributes
          typing[.foregroundColor] = fg
          textView.typingAttributes = typing

          // Apply color to all existing text
          if let storage = textView.textStorage, storage.length > 0 {
            storage.beginEditing()
            let fullRange = NSRange(location: 0, length: storage.length)
            // Only replace hard black colors and apply to uncolored text
            // This preserves user-selected colors
            storage.enumerateAttribute(.foregroundColor, in: fullRange, options: []) {
              value, range, _ in
              if let color = value as? NSColor {
                // Only replace hard black colors, preserve all other colors (including user-selected)
                if mpIsHardBlack(color) {
                  storage.removeAttribute(.foregroundColor, range: range)
                  storage.addAttribute(.foregroundColor, value: fg, range: range)
                }
                // Otherwise, keep the existing color (user-selected colors are preserved)
              } else {
                // No color set - apply default color
                storage.addAttribute(.foregroundColor, value: fg, range: range)
              }
            }
            // Also handle any ranges that don't have a color attribute at all
            var currentPos = 0
            while currentPos < storage.length {
              var rangeHasColor = false
              let checkRange = NSRange(location: currentPos, length: 1)
              storage.enumerateAttribute(.foregroundColor, in: checkRange, options: []) {
                value, _, stop in
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
                  storage.enumerateAttribute(.foregroundColor, in: nextRange, options: []) {
                    value, _, stop in
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
                storage.addAttribute(.foregroundColor, value: fg, range: uncoloredRange)
                currentPos += uncoloredLength
              } else {
                currentPos += 1
              }
            }
            storage.endEditing()
          }
        } else {
          // When we have attributed content, only replace hard black colors
          // This preserves user-selected colors
          if let storage = textView.textStorage, storage.length > 0 {
            storage.beginEditing()
            let fullRange = NSRange(location: 0, length: storage.length)

            // Only replace hard black colors and apply to uncolored text
            // This preserves user-selected colors
            storage.enumerateAttribute(.foregroundColor, in: fullRange, options: []) {
              value, range, _ in
              if let color = value as? NSColor {
                // Only replace hard black colors, preserve all other colors (including user-selected)
                if mpIsHardBlack(color) {
                  storage.removeAttribute(.foregroundColor, range: range)
                  storage.addAttribute(.foregroundColor, value: fg, range: range)
                }
                // Otherwise, keep the existing color (user-selected colors are preserved)
              } else {
                // No color set - apply default color
                storage.addAttribute(.foregroundColor, value: fg, range: range)
              }
            }
            // Also handle any ranges that don't have a color attribute at all
            var currentPos = 0
            while currentPos < storage.length {
              var rangeHasColor = false
              let checkRange = NSRange(location: currentPos, length: 1)
              storage.enumerateAttribute(.foregroundColor, in: checkRange, options: []) {
                value, _, stop in
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
                  storage.enumerateAttribute(.foregroundColor, in: nextRange, options: []) {
                    value, _, stop in
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
                storage.addAttribute(.foregroundColor, value: fg, range: uncoloredRange)
                currentPos += uncoloredLength
              } else {
                currentPos += 1
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
    // CRITICAL: Only update when user is NOT actively typing to prevent cursor jumping
    // CRITICAL: If user is actively working, sync the attributed binding FROM the text view (not overwrite it)
    // In Rich mode: ensure text storage matches provided attributed content, re-apply when it doesn't
    // CRITICAL: Only update when user is NOT actively typing to prevent cursor jumping
    // CRITICAL: If user is actively working, sync the attributed binding FROM the text view (not overwrite it)
    if isRichText, let attributed = attributed, !context.coordinator.isProcessingTextChange {
      // Check if this is an external update (input differs from what we last saw)
      // We use isEqual because attributed strings are reference types but we care about content equality
      let isExternalUpdate =
        (attributed != context.coordinator.lastAssignedAttributed)
        && !(context.coordinator.lastAssignedAttributed?.isEqual(attributed) ?? false)

      if isExternalUpdate {
        // External change - update text storage
        // Only update if it actually differs from current storage to avoid cursor jumps
        if let storage = textView.textStorage {
          let current = storage.attributedSubstring(
            from: NSRange(location: 0, length: storage.length))
          if !current.isEqual(attributed) {
            // Preserve cursor
            let savedSelection = textView.selectedRange()

            storage.beginEditing()
            storage.setAttributedString(attributed)
            storage.endEditing()
            context.coordinator.appliedInitialAttributed = true

            if savedSelection.location <= storage.length {
              textView.setSelectedRange(savedSelection)
            }
          }
        }
        context.coordinator.lastAssignedAttributed = attributed
      } else {
        // No external change - check if we need to propagate local changes
        // This handles cases where textDidChange might have been missed or we need to sync back
        // This is CRITICAL for the color picker, as the text view might lose focus/responder status
        // but we still need to preserve the color change and propagate it
        if let storage = textView.textStorage {
          let current = storage.attributedSubstring(
            from: NSRange(location: 0, length: storage.length))
          if !current.isEqual(attributed) {
            // Local change detected that isn't in the binding yet
            // Propagate it back to SwiftUI
            context.coordinator.lastAssignedAttributed = current
            DispatchQueue.main.async {
              context.coordinator.parent.onAttributedChange?(current)
            }
          }
        }
      }

      // CRITICAL: Don't modify text storage colors here - this would override user-selected colors
      // Only set default colors for typing attributes and background
      // Color replacement should only happen on initial load (in makeNSView) or when switching modes
      let isDark = mpIsDarkMode()
      let fg = isDark ? NSColor.white : NSColor.black
      let bg = isDark ? NSColor(white: 0.1, alpha: 1.0) : NSColor.white

      // Set background color (doesn't affect text colors)
      textView.backgroundColor = bg
      // textView.appearance = NSApp.effectiveAppearance
      nsView.backgroundColor = bg

      // Set typing attributes so new text gets the right color
      // But don't modify existing text storage - that would override user-selected colors
      // CRITICAL: Do not set textColor for rich text as it overwrites attributes
      // textView.textColor = fg
      var typing = textView.typingAttributes
      if typing[.foregroundColor] == nil {
          typing[.foregroundColor] = fg
          textView.typingAttributes = typing
      }
    }

    // CRITICAL: Don't force first responder status - this can interfere with cursor movement and selection
    // The text view should naturally become first responder when clicked
    // Only ensure basic properties are set, but don't interfere with user interactions

    // Prepare scroll notifications for gutter redraw during scroll
    context.coordinator.scrollView = nsView
    context.coordinator.ensureScrollNotifications()

    // Line number gutter handling (no NSRulerView)
    let ensureGutter: () -> Void = {
      DispatchQueue.main.async {
        let clip = nsView.contentView
        // Ensure layout is ready before computing visible ranges
        if let lm = textView.layoutManager, let tc = textView.textContainer {
          lm.ensureLayout(for: tc)
        }

        if context.coordinator.gutterView == nil {
          let gv = LineNumberGutterView(textView: textView, clipView: clip)
          context.coordinator.gutterView = gv
          nsView.contentView.addSubview(gv)
        }
        // Update gutter frame and inset
        let totalLines = textView.string.split(separator: "\n", omittingEmptySubsequences: false)
          .count
        let width = LineNumberGutterView.desiredWidth(
          totalLines: totalLines,
          font: context.coordinator.gutterView?.numberFont
            ?? NSFont.monospacedSystemFont(ofSize: 10, weight: .regular))
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
    if coordinator.lastAppliedFontSize == desiredFontSize
      && coordinator.lastAppliedLineSpacing == desiredLineSpacing
    {
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
      // Preserve cursor position before modifying text storage
      let savedSelection = textView.selectedRange()

      // Only apply line spacing; leave all other paragraph properties at defaults
      let paragraph = NSMutableParagraphStyle()
      paragraph.lineSpacing = max(0, desiredLineSpacing - 1) * font.pointSize * 0.5
      textStorage.beginEditing()
      textStorage.addAttribute(
        .paragraphStyle, value: paragraph, range: NSRange(location: 0, length: textStorage.length))
      textStorage.endEditing()

      // Restore cursor position after modification
      if savedSelection.location <= textStorage.length {
        textView.setSelectedRange(savedSelection)
      }
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
    // Track the last attributed string assigned from SwiftUI to detect external updates
    var lastAssignedAttributed: NSAttributedString?
    // Reentrancy/feedback guards
    var isUpdatingView = false
    var isProcessingTextChange = false  // Track when we're processing a text change from the text view
    var lastAppliedFontSize: CGFloat?
    var lastAppliedLineSpacing: CGFloat?
    // Syntax highlighting
    var lastAppliedSyntaxMode: SyntaxMode?
    var needsHighlightingUpdate = false  // Track if highlighting needs to be applied when selection clears
    var isMouseDown = false  // Track if mouse button is down (user is dragging to select)
    // Linting
    private var lintingObserver: AnyCancellable?
    private var appliedDiagnostics: Set<String> = []
    // Go to Definition event monitor
    private var goToDefinitionMonitor: Any?
    // Bracket matching
    private var bracketMatchRange: NSRange?
    // Re-entrancy guard for typing attributes to prevent infinite loops
    private var isUpdatingTypingAttributes = false

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
        let position = userInfo["position"] as? Int
      else { return }

      let range = NSRange(location: position, length: 0)
      textView.setSelectedRange(range)
      textView.scrollRangeToVisible(range)
      textView.showFindIndicator(for: range)
    }

    deinit {
      NotificationCenter.default.removeObserver(self)
      // Note: colorAppliedNotificationObserver will be automatically removed when deallocated
      // AnyCancellable automatically cancels when deallocated, so no explicit cancellation needed
      // Event monitors are automatically cleaned up when the app quits
    }

    func setupGoToDefinitionMonitoring(for textView: NSTextView) {
      guard parent.goToDefinitionEnabled else { return }

      goToDefinitionMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) {
        [weak self, weak textView] event in
        guard let self = self,
          let tv = textView,
          event.modifierFlags.contains(.command),
          self.parent.goToDefinitionEnabled,
          !tv.string.isEmpty
        else {
          return event
        }

        let location = tv.convert(event.locationInWindow, from: nil)
        let charIndex = tv.characterIndexForInsertion(at: location)
        let stringLength = (tv.string as NSString).length

        if charIndex >= 0 && charIndex < stringLength {
          self.handleGoToDefinition(at: charIndex)
          return nil  // Consume the event to prevent normal mouse handling
        }

        return event
      }
    }

    func setupMouseTracking(for textView: NSTextView) {
      // Use a more targeted approach - only monitor events within the text view's window
      // This avoids interfering with global event handling
      guard let window = textView.window else { return }

      // Monitor mouse down events to detect when user starts dragging to select
      _ = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) {
        [weak self, weak textView] event in
        // Only track if the event is in our text view's window
        guard let self = self,
          let tv = textView,
          event.window === window
        else {
          return event
        }
        // Check if the click is actually in the text view
        let locationInWindow = event.locationInWindow
        if let locationInView = tv.superview?.convert(locationInWindow, from: nil),
          tv.frame.contains(locationInView)
        {
          self.isMouseDown = true
        }
        return event  // Always return the event so text view can handle it normally
      }

      // Monitor mouse up events to detect when user finishes selecting
      _ = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseUp]) { [weak self] event in
        guard let self = self,
          event.window === window
        else {
          return event
        }
        self.isMouseDown = false
        // When mouse is released, try to apply any pending highlighting
        if self.needsHighlightingUpdate {
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let tv = self.textView,
              let storage = tv.textStorage,
              storage.length > 0,
              !self.parent.isRichText,
              tv.selectedRange().length == 0
            {
              self.applySyntaxHighlighting(to: storage, syntaxMode: self.parent.syntaxMode)
              self.lastAppliedSyntaxMode = self.parent.syntaxMode
              self.needsHighlightingUpdate = false
            }
          }
        }
        return event  // Always return the event so text view can handle it normally
      }
    }

    func ensureScrollNotifications() {
      guard let clipView = scrollView?.contentView else { return }
      guard !scrollNotificationsSetup else { return }
      scrollNotificationsSetup = true
      clipView.postsBoundsChangedNotifications = true
      NotificationCenter.default.addObserver(
        self, selector: #selector(Coordinator.clipViewBoundsDidChange(_:)),
        name: NSView.boundsDidChangeNotification, object: clipView)
    }

    @objc private func clipViewBoundsDidChange(_ notification: Notification) {
      layoutGutter()
      gutterView?.needsDisplay = true
    }

    func layoutGutter() {
      guard let clip = scrollView?.contentView else { return }
      guard let gutterView = gutterView else { return }
      let clipBounds = clip.bounds
      let frame = NSRect(
        x: clipBounds.minX, y: clipBounds.minY, width: gutterWidth, height: clipBounds.height)
      if gutterView.frame != frame {
        gutterView.frame = frame
        gutterView.needsDisplay = true
      }
    }

    func updateTextInsets() {
      guard let tv = textView else { return }
      let newInset = NSSize(
        width: baseInset.width + (parent.showLineNumbers ? gutterWidth : 0),
        height: baseInset.height)
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

      guard let tv = textView else {
        print("[SyntaxHighlight] No text view")
        return
      }

      // CRITICAL: Ensure text view remains selectable before any operations
      if !tv.isSelectable {
        tv.isSelectable = true
      }

      // Skip highlighting if user is actively dragging with mouse (most reliable check)
      if isMouseDown {
        print("[SyntaxHighlight] Skipping - mouse is down (user is dragging)")
        needsHighlightingUpdate = true
        return
      }

      // Skip highlighting if user has an active selection
      // Modifying text storage attributes will clear the selection, so we defer until selection is cleared
      let currentSelection = tv.selectedRange()
      if currentSelection.length > 0 {
        print(
          "[SyntaxHighlight] Skipping - user has active selection (length: \(currentSelection.length))"
        )
        needsHighlightingUpdate = true  // Mark that we need to apply when selection clears
        return
      }

      // Clear the flag since we're applying now
      needsHighlightingUpdate = false

      let text = storage.string
      var appliedCount = 0

      // Check for custom syntax mode first
      let patterns: [(pattern: String, color: Color)]
      if let ext = parent.fileExtension?.lowercased(),
        let customMode = CustomSyntaxModeManager.shared.customModeForExtension(ext)
      {
        // Use custom mode patterns
        let colorScheme: ColorScheme = .dark  // Could be improved to detect actual scheme
        patterns = CustomSyntaxModeManager.shared.syntaxPatterns(
          for: customMode, colorScheme: colorScheme)
        print("[SyntaxHighlight] Using custom syntax mode: \(customMode.name)")
      } else {
        // Use built-in mode patterns
        patterns = syntaxMode.syntaxPatterns
      }

      print(
        "[SyntaxHighlight] Applying highlighting for \(syntaxMode.displayName), text length: \(text.count), patterns: \(patterns.count)"
      )
      print("[SyntaxHighlight] Sample text (first 100 chars): \(String(text.prefix(100)))")

      // Use a mutable copy to track which ranges have been colored
      var coloredRanges: Set<NSRange> = []

      storage.beginEditing()

      // Apply each syntax pattern
      // Process in order - later patterns can overwrite earlier ones if they overlap
      for (patternString, color) in patterns {
        // Convert SwiftUI Color to NSColor properly
        #if os(macOS)
          let nsColor = NSColor(color)
        #else
          let nsColor = UIColor(color)
        #endif
        var patternMatches = 0

        // Use NSRegularExpression to avoid Regex type issues with capture groups
        do {
          let regex = try NSRegularExpression(pattern: patternString, options: [])
          let nsString = text as NSString
          let range = NSRange(location: 0, length: nsString.length)
          regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            if let match = match {
              let nsRange = match.range
              if nsRange.location != NSNotFound
                && nsRange.location + nsRange.length <= storage.length
              {
                // Use addAttribute instead of setAttributes to preserve other attributes
                storage.addAttribute(.foregroundColor, value: nsColor, range: nsRange)
                coloredRanges.insert(nsRange)
                appliedCount += 1
                patternMatches += 1
              }
            }
          }
        } catch {
          print("[SyntaxHighlight] Invalid regex pattern '\(patternString)': \(error)")
        }

        if patternMatches > 0 {
          print("[SyntaxHighlight] Pattern matched \(patternMatches) times, color: \(nsColor)")
        }
      }

      // Set default text color for any ranges that weren't colored
      // Use explicit colors based on appearance
      let isDark = mpIsDarkMode()
      let defaultColor = isDark ? NSColor.white : NSColor.black
      let fullRange = NSRange(location: 0, length: storage.length)

      // Find ranges that don't have colors
      var currentPos = 0
      while currentPos < storage.length {
        var rangeHasColor = false
        let checkRange = NSRange(location: currentPos, length: 1)
        storage.enumerateAttribute(.foregroundColor, in: checkRange, options: []) {
          value, _, stop in
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
            storage.enumerateAttribute(.foregroundColor, in: nextRange, options: []) {
              value, _, stop in
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

      // CRITICAL: After modifying text storage, ensure text view is still selectable
      // Modifying attributes can sometimes cause the text view to lose selectability
      if let tv = textView {
        // Ensure selectability is maintained
        if !tv.isSelectable {
          tv.isSelectable = true
        }
        // Force redraw
        tv.needsDisplay = true
      }

      // Verify colors were applied
      var verifiedCount = 0
      storage.enumerateAttribute(.foregroundColor, in: fullRange, options: []) { value, _, _ in
        if value != nil {
          verifiedCount += 1
        }
      }

      // Debug: print if we applied any colors
      print(
        "[SyntaxHighlight] Total: Applied \(appliedCount) syntax color ranges, verified \(verifiedCount) total color ranges for \(syntaxMode.displayName)"
      )
    }

    func textDidChange(_ notification: Notification) {
      guard let tv = textView else { return }
      print(
        "[CocoaTextView] textDidChange fired. RichText: \(parent.isRichText), Length: \(tv.string.count)"
      )
      // Avoid mutating SwiftUI state if we're inside an update pass
      if isUpdatingView { return }

      // Mark that we're processing a text change from the text view
      // This prevents updateNSView from overwriting the text and clearing selection
      isProcessingTextChange = true

      let newText = tv.string

      // CRITICAL: Defer state modifications to avoid "Modifying state during view update" warning
      // This ensures we're not modifying SwiftUI state during a view update cycle
      DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }
        if self.parent.text != newText {
          self.parent.text = newText
          self.parent.onTextChange?(newText)
        }

        // If rich text, also propagate attributed string so styles persist across tab switches
        if self.parent.isRichText, let storage = tv.textStorage {
          let range = NSRange(location: 0, length: storage.length)
          let snapshot = storage.attributedSubstring(from: range)
          // Update our local tracking so we don't treat the echo back from SwiftUI as an external change
          self.lastAssignedAttributed = snapshot
          self.parent.onAttributedChange?(snapshot)
        }
      }

      // CRITICAL: Ensure typing attributes have the correct color for plain text mode
      // This ensures newly typed text is visible in dark mode
      // This doesn't modify SwiftUI state, so it's safe to do synchronously
      if !parent.isRichText {
        let isDark = mpIsDarkMode()
        let fg = isDark ? NSColor.white : NSColor.black
        let bg = isDark ? NSColor(white: 0.1, alpha: 1.0) : NSColor.white
        var typing = tv.typingAttributes
        if typing[.foregroundColor] as? NSColor != fg {
          typing[.foregroundColor] = fg
          tv.typingAttributes = typing
        }
        // Also ensure textColor and background are set
        if tv.textColor != fg {
          tv.textColor = fg
        }
        tv.backgroundColor = bg
        // tv.appearance = NSApp.effectiveAppearance
      }

      // Update gutter width (doesn't modify SwiftUI state, safe to do synchronously)
      if parent.showLineNumbers {
        let lines = newText.split(separator: "\n", omittingEmptySubsequences: false).count
        gutterWidth = LineNumberGutterView.desiredWidth(
          totalLines: lines,
          font: gutterView?.numberFont ?? NSFont.monospacedSystemFont(ofSize: 10, weight: .regular))
        updateTextInsets()
        gutterView?.needsDisplay = true
      }

      // Trigger linting if enabled (doesn't modify SwiftUI state directly, safe to do synchronously)
      if parent.lintingEnabled, let linter = parent.linter {
        linter.lint(newText, syntaxMode: parent.syntaxMode)
      }

      // Reset the flag after a very short delay to allow SwiftUI to process the update
      // But keep it short so we don't block legitimate external updates
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
        self?.isProcessingTextChange = false
      }

      // TEMPORARILY DISABLED: Apply syntax highlighting if not in rich text mode
      // Syntax highlighting is disabled to fix cursor movement and selection issues
      // TODO: Re-enable with a better implementation that doesn't interfere with user input
      /*
      if !parent.isRichText, let storage = tv.textStorage, storage.length > 0 {
          // Mark that we need highlighting update
          needsHighlightingUpdate = true
          // Delay highlighting to give user time to select text if they want to
          // This prevents highlighting from interfering with selection attempts
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
              guard let self = self,
                    let tv = self.textView,
                    let storage = tv.textStorage,
                    storage.length > 0,
                    !self.parent.isRichText else { return }
              // Only apply if user doesn't have a selection and mouse isn't down
              if tv.selectedRange().length == 0 && !self.isMouseDown {
                  self.applySyntaxHighlighting(to: storage, syntaxMode: self.parent.syntaxMode)
                  self.lastAppliedSyntaxMode = self.parent.syntaxMode
                  self.needsHighlightingUpdate = false
              }
          }
      }
      */
    }

    func textViewDidChangeSelection(_ notification: Notification) {
      gutterView?.needsDisplay = true
      updateCursorPosition()
      updateBracketMatching()

      // Re-apply syntax highlighting when selection is cleared
      // This ensures highlighting gets applied after user finishes selecting/copying text
      if let tv = textView,
        tv.selectedRange().length == 0,
        !parent.isRichText,
        let storage = tv.textStorage,
        storage.length > 0
      {
        // Only re-apply if we need an update (text changed while selection was active)
        if needsHighlightingUpdate {
          applySyntaxHighlighting(to: storage, syntaxMode: parent.syntaxMode)
          lastAppliedSyntaxMode = parent.syntaxMode
          needsHighlightingUpdate = false
        }
      }
    }

    func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
      // Always allow text changes
      return true
    }

    func textShouldBeginEditing(_ textObject: NSText) -> Bool {
      return true
    }

    func textShouldEndEditing(_ textObject: NSText) -> Bool {
      return true
    }

    private func updateBracketMatching() {
      guard let tv = textView, let storage = tv.textStorage else { return }

      // Remove previous bracket highlighting
      if let oldRange = bracketMatchRange {
        storage.removeAttribute(.backgroundColor, range: oldRange)
        // CRITICAL: Do NOT remove foreground color, as we only set background color
        // Removing foreground color wipes out user's syntax highlighting or manual color selection
        // storage.removeAttribute(.foregroundColor, range: oldRange)
      }
      bracketMatchRange = nil

      let selectedRange = tv.selectedRange()
      guard selectedRange.length == 0, selectedRange.location < storage.length else { return }

      let string = storage.string as NSString
      let charIndex = selectedRange.location

      // Get character at cursor
      guard charIndex < string.length else { return }
      let char = string.character(at: charIndex)
      let charStr = String(Character(UnicodeScalar(char)!))

      // Define bracket pairs
      let bracketPairs: [(String, String)] = [
        ("(", ")"),
        ("[", "]"),
        ("{", "}"),
        ("<", ">"),
      ]

      var openingBracket: String?
      var closingBracket: String?
      var searchDirection: Int = 0  // 1 = forward, -1 = backward
      var bracketIndex: Int = -1  // Position of bracket to match

      // Check if cursor is on an opening bracket
      for (open, close) in bracketPairs {
        if charStr == open {
          openingBracket = open
          closingBracket = close
          searchDirection = 1
          bracketIndex = charIndex
          break
        } else if charStr == close {
          openingBracket = open
          closingBracket = close
          searchDirection = -1
          bracketIndex = charIndex
          break
        }
      }

      // Also check character before cursor
      if openingBracket == nil && charIndex > 0 {
        let prevChar = string.character(at: charIndex - 1)
        let prevCharStr = String(Character(UnicodeScalar(prevChar)!))
        for (open, close) in bracketPairs {
          if prevCharStr == open {
            openingBracket = open
            closingBracket = close
            searchDirection = 1
            bracketIndex = charIndex - 1
            break
          } else if prevCharStr == close {
            openingBracket = open
            closingBracket = close
            searchDirection = -1
            bracketIndex = charIndex - 1
            break
          }
        }
      }

      guard let open = openingBracket, let close = closingBracket, bracketIndex >= 0 else { return }

      // Check if we're inside a string or comment (simplified check)
      let syntaxMode = parent.syntaxMode
      let isInString = isInsideString(at: bracketIndex, in: string, syntaxMode: syntaxMode)
      let isInComment = isInsideComment(at: bracketIndex, in: string, syntaxMode: syntaxMode)

      if isInString || isInComment {
        return  // Don't match brackets inside strings/comments
      }

      // Find matching bracket (skip strings and comments)
      var matchRange: NSRange?
      if searchDirection == 1 {
        // Search forward for closing bracket
        var depth = 1
        var pos = bracketIndex + 1
        var inString = false
        var escapeNext = false

        while pos < string.length {
          let ch = string.character(at: pos)
          let chStr = String(Character(UnicodeScalar(ch)!))

          // Track string/comment state
          if !escapeNext {
            if chStr == "\"" {
              inString.toggle()
            } else if syntaxMode.lineComment.count > 0
              && string.substring(
                with: NSRange(
                  location: pos, length: min(syntaxMode.lineComment.count, string.length - pos)))
                == syntaxMode.lineComment
              && !inString
            {
              // Line comment starts here, skip to end of line
              let lineRange = string.lineRange(for: NSRange(location: pos, length: 0))
              pos = lineRange.location + lineRange.length - 1
              continue
            }
          }
          escapeNext = (chStr == "\\" && inString)

          if !inString {
            if chStr == open {
              depth += 1
            } else if chStr == close {
              depth -= 1
              if depth == 0 {
                matchRange = NSRange(location: pos, length: 1)
                break
              }
            }
          }
          pos += 1
        }
      } else {
        // Search backward for opening bracket
        var depth = 1
        var pos = bracketIndex - 1
        var inString = false
        var escapeNext = false

        while pos >= 0 {
          let ch = string.character(at: pos)
          let chStr = String(Character(UnicodeScalar(ch)!))

          // Track string state (simplified backward search)
          if !escapeNext && chStr == "\"" {
            inString.toggle()
          }
          escapeNext = (chStr == "\\" && inString)

          if !inString {
            if chStr == close {
              depth += 1
            } else if chStr == open {
              depth -= 1
              if depth == 0 {
                matchRange = NSRange(location: pos, length: 1)
                break
              }
            }
          }
          pos -= 1
        }
      }

      // Highlight matching bracket
      if let match = matchRange {
        let highlightColor = NSColor.systemBlue.withAlphaComponent(0.3)
        storage.addAttribute(.backgroundColor, value: highlightColor, range: match)
        bracketMatchRange = match
        tv.needsDisplay = true
      }
    }

    private func isInsideString(at index: Int, in string: NSString, syntaxMode: SyntaxMode) -> Bool
    {
      var inString = false
      var escapeNext = false
      for i in 0..<min(index, string.length) {
        let ch = string.character(at: i)
        let chStr = String(Character(UnicodeScalar(ch)!))
        if escapeNext {
          escapeNext = false
          continue
        }
        if chStr == "\\" {
          escapeNext = true
          continue
        }
        if chStr == "\"" {
          inString.toggle()
        }
      }
      return inString
    }

    private func isInsideComment(at index: Int, in string: NSString, syntaxMode: SyntaxMode) -> Bool
    {
      let lineComment = syntaxMode.lineComment
      if lineComment.isEmpty { return false }

      // Check if we're on a line that starts with a comment
      let lineRange = string.lineRange(for: NSRange(location: index, length: 0))
      let line = string.substring(with: lineRange)
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      return trimmed.hasPrefix(lineComment)
    }

    private func updateCursorPosition() {
      guard let tv = textView else { return }
      let selectedRange = tv.selectedRange()
      let position = selectedRange.location
      let string = tv.string as NSString

      // Calculate line and column
      var line = 1
      var column = 1
      var currentPos = 0

      string.enumerateSubstrings(
        in: NSRange(location: 0, length: min(position, string.length)), options: .byLines
      ) { (_, _, enclosingRange, stop) in
        if enclosingRange.location + enclosingRange.length <= position {
          line += 1
          currentPos = enclosingRange.location + enclosingRange.length
        } else {
          stop.pointee = true
        }
      }

      // Calculate column within the line
      if currentPos < position {
        let lineRange = string.lineRange(for: NSRange(location: position, length: 0))
        column = position - lineRange.location + 1
      }

      parent.onCursorChange?(line, column, position)
    }

    // Handle attribute changes (e.g. from Color Panel)
    func textViewDidChangeTypingAttributes(_ notification: Notification) {
      guard let tv = textView, parent.isRichText else { return }

      // CRITICAL: When typing attributes change, we must ensure they are preserved
      // If we don't propagate them, the next update loop might revert them
      
      if let storage = tv.textStorage {
        let range = NSRange(location: 0, length: storage.length)
        let snapshot = storage.attributedSubstring(from: range)
        
        // CRITICAL: We must also capture the typing attributes effectively
        // Since attributed string doesn't store "typing attributes" directly, 
        // we just rely on the fact that the TEXT VIEW has them. 
        // However, we need to ensure we don't overwrite them in updateNSView.
        // The fix in updateNSView (checking for nil) handles the preservation.
        // Here we just ensure state stays in sync.

        // Update local tracking
        lastAssignedAttributed = snapshot

        // Propagate to SwiftUI
        DispatchQueue.main.async { [weak self] in
          self?.parent.onAttributedChange?(snapshot)
        }
      }
    }

    // MARK: - Linting Diagnostics

    func applyLintingDiagnostics(_ diagnostics: [Diagnostic]) {
      guard let tv = textView, parent.lintingEnabled else {
        print("[Linting] Skipped - linting disabled or no text view")
        return
      }
      guard let storage = tv.textStorage, let layoutManager = tv.layoutManager,
        tv.textContainer != nil
      else {
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
        guard
          diagnosticRange.location < storageLength
            && diagnosticRange.location + diagnosticRange.length <= storageLength
        else {
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
        if finalRange.location < storageLength
          && finalRange.location + finalRange.length <= storageLength
        {
          storage.addAttribute(.underlineStyle, value: underlineStyle.rawValue, range: finalRange)
          storage.addAttribute(.underlineColor, value: underlineColor, range: finalRange)
          appliedCount += 1
          print(
            "[Linting] Applied \(diagnostic.severity) underline at line \(diagnostic.line): \(diagnostic.message)"
          )
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
        print(
          "[Linting] getLineRange: Line \(lineNumber) out of range (total lines: \(lines.count))")
        return NSRange(location: NSNotFound, length: 0)
      }

      // Calculate the range for the requested line by finding line boundaries
      var currentLocation = 0
      for (index, line) in lines.enumerated() {
        let lineIndex = index + 1  // 1-based line numbers

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
          let nextChar = string.substring(
            with: NSRange(
              location: currentLocation, length: min(2, string.length - currentLocation)))
          if nextChar.hasPrefix("\r\n") {
            currentLocation += 2
          } else if nextChar.hasPrefix("\n") || nextChar.hasPrefix("\r") {
            currentLocation += 1
          }
        }
      }

      // Should not reach here, but return not found if we do
      print(
        "[Linting] getLineRange: Could not find line \(lineNumber) (total lines: \(lines.count))")
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
        if trimmed.contains("func \(word)") || trimmed.contains("class \(word)")
          || trimmed.contains("struct \(word)") || trimmed.contains("enum \(word)")
          || trimmed.contains("var \(word)") || trimmed.contains("let \(word)")
        {
          foundLine = index + 1
          break
        }

        // Python: def, class
        if trimmed.contains("def \(word)") || trimmed.contains("class \(word)") {
          foundLine = index + 1
          break
        }

        // JavaScript: function, class, const, let, var
        if trimmed.contains("function \(word)") || trimmed.contains("class \(word)")
          || trimmed.contains("const \(word)") || trimmed.contains("let \(word)")
          || trimmed.contains("var \(word)")
        {
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
    return CGFloat(8 + digits * 8) + 12  // approximate matching previous padding
  }

  override func draw(_ dirtyRect: NSRect) {
    guard let textView = textView,
      let layoutManager = textView.layoutManager,
      let textContainer = textView.textContainer
    else { return }

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
      .foregroundColor: lineNumberColor,
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

    layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) {
      (_, usedRect, _, glyphRange, _) in
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

class MacPadTextView: NSTextView {
  // Enforce editable state to prevent it from being accidentally disabled
  override var isEditable: Bool {
    get { return true }
    set { super.isEditable = true }
  }

  override func deleteBackward(_ sender: Any?) {
    super.deleteBackward(sender)
  }
}
