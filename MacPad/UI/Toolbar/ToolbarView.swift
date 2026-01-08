import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ToolbarView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings
    @AppStorage("application.textMode") private var textMode: String = "plain"
    @State private var showingFindReplace = false
    
    var isRichText: Bool { textMode.lowercased() == "rich" }
    
    var body: some View {
        HStack(spacing: 14) {
            // File group
            Group {
                Button(action: newFile) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue, .green)
                }
                    .help("New File")
                Button(action: openFile) {
                    Image(systemName: "folder")
                        .font(.system(size: 14))
                        .foregroundStyle(.yellow)
                }
                    .help("Open File…")
                Divider()
            }
            
            // Edit group
            Group {
                Button(action: cut) { Image(systemName: "scissors").foregroundStyle(.red) }
                    .help("Cut")
                Button(action: copyText) { Image(systemName: "doc.on.doc").foregroundStyle(.teal) }
                    .help("Copy")
                Button(action: paste) { Image(systemName: "doc.on.clipboard").foregroundStyle(.green) }
                    .help("Paste")
                Button(action: selectAll) { Image(systemName: "text.cursor").foregroundStyle(.cyan) }
                    .help("Select All")
                Divider()
            }
            
            // Search/Replace
            Button(action: { showingFindReplace = true }) { Image(systemName: "text.magnifyingglass").foregroundStyle(.purple) }
                .help("Search / Replace")
            Divider()
            
            // Save actions
            Group {
                Button(action: save) { Image(systemName: "square.and.arrow.down").foregroundStyle(.blue) }
                    .help("Save")
                Button(action: saveAs) { Image(systemName: "square.and.arrow.down.on.square").foregroundStyle(.indigo) }
                    .help("Save As…")
                Divider()
            }
            
            // Undo/Redo
            Group {
                Button(action: undo) { Image(systemName: "arrow.uturn.backward").foregroundStyle(.orange) }
                    .help("Undo")
                Button(action: redo) { Image(systemName: "arrow.uturn.forward").foregroundStyle(.orange) }
                    .help("Redo")
                Divider()
            }
            
            // Font style popover
            Button(action: { showingFontPopover.toggle(); syncFontTogglesFromSelection() }) {
                Image(systemName: "textformat")
                    .foregroundStyle(.pink)
            }
            .help("Font Style…")
            .popover(isPresented: $showingFontPopover, arrowEdge: .top) {
                FontStylePopover(
                    isPresented: $showingFontPopover,
                    bold: $styleBold,
                    italic: $styleItalic,
                    underline: $styleUnderline,
                    strikethrough: $styleStrikethrough,
                    applyToSelection: applyStyleToSelection,
                    setForTyping: setStyleForTyping
                )
                .frame(width: 260)
                .padding(12)
            }
            
            // Text color palette (moved from TabStrip)
            Button(action: { showingColorPopover.toggle(); if showingColorPopover { syncColorFromSelection() } }) {
                Image(systemName: "paintpalette")
                    .foregroundStyle(.red, .yellow, .blue)
            }
            .help(isRichText ? "Text Color…" : "Text Color (Rich Text only)")
            .disabled(!isRichText)
            .popover(isPresented: $showingColorPopover, arrowEdge: .top) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Text Color").font(.headline)
                    if !isRichText {
                        Text("Enable Rich Text in Preferences → Application to change text color.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    ColorPicker("Color", selection: $chosenColor, supportsOpacity: true)
                        .disabled(!isRichText)
                        .onChange(of: chosenColor) {
                            applyChosenColor()
                        }
                    Toggle("Use for new typing", isOn: $applyColorToTyping)
                        .disabled(!isRichText)
                    HStack {
                        Button("Apply to Selection") { applyChosenColor() }
                            .disabled(!isRichText)
                        Spacer()
                        Button("Close") { showingColorPopover = false }
                    }
                }
                .padding(12)
                .frame(width: 260)
            }
            
                Spacer()
            // Preferences gear at far right
            Button(action: openPreferences) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(.gray)
            }
                .help("Preferences…")
        }
        .buttonStyle(.plain)
        .symbolRenderingMode(.multicolor)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity)
        .background(.bar)
        .sheet(isPresented: $showingFindReplace) {
            if let doc = appState.getDocument(id: appState.selectedTab) {
                FindReplaceSheet(isPresented: $showingFindReplace)
                    .environmentObject(doc)
                    .frame(minWidth: 520, minHeight: 420)
            } else {
                Text("No document selected")
                    .padding()
            }
        }
    }
    
    // MARK: - State for font style popover
    @State private var showingFontPopover = false
    @State private var styleBold = false
    @State private var styleItalic = false
    @State private var styleUnderline = false
    @State private var styleStrikethrough = false

    // MARK: - State for color palette
    @State private var showingColorPopover = false
    @State private var chosenColor: Color = .red
    @State private var applyColorToTyping: Bool = true

    // MARK: - Actions (Responder chain where possible)
    private func performResponderAction(_ selector: Selector) {
        // Try the standard responder chain first
        let handled = NSApp.sendAction(selector, to: nil, from: nil)
        if !handled {
            // Fallback: if the first responder is an NSTextView, invoke directly
            if let textView = NSApp.keyWindow?.firstResponder as? NSTextView {
                _ = textView.tryToPerform(selector, with: nil)
            }
        }
    }

    private func cut() { performResponderAction(#selector(NSText.cut(_:))) }
    private func copyText() { performResponderAction(#selector(NSText.copy(_:))) }
    private func paste() { performResponderAction(#selector(NSText.paste(_:))) }
    private func selectAll() { performResponderAction(#selector(NSText.selectAll(_:))) }
    private func undo() { performResponderAction(Selector(("undo:"))) }
    private func redo() { performResponderAction(Selector(("redo:"))) }

    private func openPreferences() {
        // Prefer SwiftUI's Settings window opener when available
        if #available(macOS 13.0, *) {
            openSettings()
        } else {
            // Fallback to AppKit selector on older macOS
            _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    private func newFile() {
        appState.addDocument(name: "Untitled", content: "", path: nil, syntaxMode: .swift)
    }
    
    private func openFile() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [] // allow any
        if panel.runModal() == .OK {
            for url in panel.urls {
                openURLIntoEditor(url)
            }
        }
    }
    
    private func openURLIntoEditor(_ url: URL) {
        let ext = url.pathExtension.lowercased()
        var attributed: NSAttributedString? = nil
        var plain: String = ""
        // Try attributed formats first for rich text
        if ext == "rtf" || ext == "rtfd" || ext == "html" || ext == "htm" {
            if let attr = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
                attributed = attr
                plain = attr.string
            }
        }
        if plain.isEmpty {
            // Fallback to reading as UTF-8 plain text
            if let txt = try? String(contentsOf: url, encoding: .utf8) {
                plain = txt
            } else if let data = try? Data(contentsOf: url), let txt = String(data: data, encoding: .utf8) {
                plain = txt
            }
        }
        appState.addDocument(
            name: url.lastPathComponent,
            content: plain,
            path: url,
            syntaxMode: SyntaxMode.from(path: url) ?? .swift,
            attributedContent: attributed
        )
    }
    
    private func save() {
        guard let doc = appState.getDocument(id: appState.selectedTab) else { return }
        guard let url = doc.path else { saveAs(); return }
        let ext = url.pathExtension.lowercased()
        let type: UTType
        switch ext {
        case "rtf": type = .rtf
        case "html", "htm": type = .html
        default: type = .plainText
        }
        do {
            try writeDocument(doc, to: url, as: type)
            doc.isModified = false
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to Save"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func saveAs() {
        guard let doc = appState.getDocument(id: appState.selectedTab) else { return }
        // Use unified helper which allows picking explicit format and syncs filename extension
        guard let result = SavePanelHelper.presentSavePanel(suggestedName: doc.name, initialURL: doc.path) else { return }
        do {
            try writeDocument(doc, to: result.url, as: result.type)
            doc.path = result.url
            doc.name = result.url.lastPathComponent
            doc.isModified = false
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to Save As"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // Write helper: outputs plain text, RTF, or HTML based on type
    private func writeDocument(_ doc: Document, to url: URL, as type: UTType) throws {
        if type == .plainText {
            try doc.content.write(to: url, atomically: true, encoding: .utf8)
            return
        }
        // For rich formats, capture the current attributed string from the focused editor if possible
        if let tv = focusedTextView() {
            let attr = tv.attributedString()
            let full = NSRange(location: 0, length: attr.length)
            if type == .rtf {
                let data = try attr.data(from: full, documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf])
                try data.write(to: url, options: .atomic)
            } else if type == .html {
                let data = try attr.data(from: full, documentAttributes: [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue
                ])
                try data.write(to: url, options: .atomic)
            } else {
                // Fallback to plain text if an unknown type is provided
                try doc.content.write(to: url, atomically: true, encoding: .utf8)
            }
        } else {
            // No active editor; best effort: export plain text
            try doc.content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Font style helpers
    private func focusedTextView() -> NSTextView? {
        // Try to get the first responder as NSTextView
        if let textView = NSApp.keyWindow?.firstResponder as? NSTextView {
            return textView
        }
        
        // If that doesn't work, try to find it in the key window's view hierarchy
        // This is needed because in SwiftUI with NSViewRepresentable, the first responder
        // might be the scroll view or another wrapper view
        if let window = NSApp.keyWindow,
           let contentView = window.contentView {
            // Search for NSTextView in the view hierarchy
            func findTextView(in view: NSView) -> NSTextView? {
                if let textView = view as? NSTextView {
                    return textView
                }
                for subview in view.subviews {
                    if let textView = findTextView(in: subview) {
                        return textView
                    }
                }
                return nil
            }
            return findTextView(in: contentView)
        }
        
        return nil
    }

    private func syncFontTogglesFromSelection() {
        guard let tv = focusedTextView() else { return }
        let attrs: [NSAttributedString.Key: Any]
        if tv.selectedRange.length > 0, let textStorage = tv.textStorage, tv.selectedRange.location < textStorage.length {
            let location = max(0, min(tv.selectedRange.location, textStorage.length - 1))
            attrs = textStorage.attributes(at: location, effectiveRange: nil)
        } else {
            attrs = tv.typingAttributes
        }
        if let font = attrs[.font] as? NSFont {
            let traits = font.fontDescriptor.symbolicTraits
            styleBold = traits.contains(.bold)
            styleItalic = traits.contains(.italic)
        } else {
            styleBold = false; styleItalic = false
        }
        if let u = attrs[.underlineStyle] as? NSNumber {
            styleUnderline = u.intValue != 0
        } else { styleUnderline = false }
        if let s = attrs[.strikethroughStyle] as? NSNumber {
            styleStrikethrough = s.intValue != 0
        } else { styleStrikethrough = false }
    }

    private func buildFont(from base: NSFont?, bold: Bool, italic: Bool) -> NSFont? {
        guard let base = base ?? NSFont.monospacedSystemFont(ofSize: 14, weight: .regular) as NSFont? else { return nil }
        let fm = NSFontManager.shared
        var f = base
        // Toggle bold
        if bold {
            f = fm.convert(f, toHaveTrait: .boldFontMask)
        } else {
            f = fm.convert(f, toNotHaveTrait: .boldFontMask)
        }
        // Toggle italic
        if italic {
            f = fm.convert(f, toHaveTrait: .italicFontMask)
        } else {
            f = fm.convert(f, toNotHaveTrait: .italicFontMask)
        }
        return f
    }

    private func applyStyleToSelection() {
        guard let tv = focusedTextView() else { return }
        let range = tv.selectedRange
        let textStorage = tv.textStorage
        let baseFont = (tv.typingAttributes[.font] as? NSFont) ?? tv.font
        guard let newFont = buildFont(from: baseFont, bold: styleBold, italic: styleItalic) else { return }
        textStorage?.beginEditing()
        if range.length > 0 {
            if let r = Range(range, in: tv.string) { _ = r }
            textStorage?.addAttribute(.font, value: newFont, range: range)
            textStorage?.addAttribute(.underlineStyle, value: styleUnderline ? NSUnderlineStyle.single.rawValue : 0, range: range)
            textStorage?.addAttribute(.strikethroughStyle, value: styleStrikethrough ? NSUnderlineStyle.single.rawValue : 0, range: range)
        } else {
            // No selection, update typing attributes as a convenience
            var attrs = tv.typingAttributes
            attrs[.font] = newFont
            attrs[.underlineStyle] = styleUnderline ? NSUnderlineStyle.single.rawValue : 0
            attrs[.strikethroughStyle] = styleStrikethrough ? NSUnderlineStyle.single.rawValue : 0
            tv.typingAttributes = attrs
        }
        textStorage?.endEditing()
        tv.setNeedsDisplay(tv.bounds)
    }

    private func setStyleForTyping() {
        guard let tv = focusedTextView() else { return }
        let baseFont = (tv.typingAttributes[.font] as? NSFont) ?? tv.font
        guard let newFont = buildFont(from: baseFont, bold: styleBold, italic: styleItalic) else { return }
        var attrs = tv.typingAttributes
        attrs[.font] = newFont
        attrs[.underlineStyle] = styleUnderline ? NSUnderlineStyle.single.rawValue : 0
        attrs[.strikethroughStyle] = styleStrikethrough ? NSUnderlineStyle.single.rawValue : 0
        tv.typingAttributes = attrs
    }

    private func syncColorFromSelection() {
        guard let tv = focusedTextView() else { return }
        let attrs: [NSAttributedString.Key: Any]
        if tv.selectedRange.length > 0, let textStorage = tv.textStorage, tv.selectedRange.location < textStorage.length {
            let location = max(0, min(tv.selectedRange.location, textStorage.length - 1))
            attrs = textStorage.attributes(at: location, effectiveRange: nil)
        } else {
            attrs = tv.typingAttributes
        }
        
        if let color = attrs[.foregroundColor] as? NSColor {
            // Convert NSColor to Color, ensuring we have a valid color space
            if let srgb = color.usingColorSpace(.sRGB) {
                chosenColor = Color(nsColor: srgb)
            } else {
                chosenColor = Color(nsColor: color)
            }
        }
    }

    // MARK: - Color palette actions
    private func applyChosenColor() {
        guard isRichText else { 
            print("[ColorPicker] Rich text mode not enabled")
            return 
        }
        guard let tv = focusedTextView() else { 
            print("[ColorPicker] Could not find focused text view")
            return 
        }
        guard let doc = appState.getDocument(id: appState.selectedTab) else { 
            print("[ColorPicker] Could not find document")
            return 
        }
        guard let storage = tv.textStorage else {
            print("[ColorPicker] Text storage is nil")
            return
        }
        
        let nsColor = NSColor(chosenColor)
        let range = tv.selectedRange
        print("[ColorPicker] Applying color \(nsColor) to range: \(range)")
        
        storage.beginEditing()
        if range.length > 0 {
            storage.addAttribute(.foregroundColor, value: nsColor, range: range)
            print("[ColorPicker] Applied color to selection (length: \(range.length))")
        } else {
            print("[ColorPicker] No selection - applying to typing attributes only")
        }
        storage.endEditing()
        
        if applyColorToTyping {
            var attrs = tv.typingAttributes
            attrs[.foregroundColor] = nsColor
            tv.typingAttributes = attrs
            print("[ColorPicker] Updated typing attributes")
        }
        
        // Force immediate display update
        tv.setNeedsDisplay(tv.bounds)
        tv.displayIfNeeded()
        
        // CRITICAL: Update document's attributedContent immediately so updateNSView doesn't overwrite the color change
        // Use async to ensure this happens after the text storage update is complete
        DispatchQueue.main.async {
            let fullRange = NSRange(location: 0, length: storage.length)
            let updatedAttributed = storage.attributedSubstring(from: fullRange)
            doc.attributedContent = updatedAttributed
            doc.isModified = true
            print("[ColorPicker] Updated document attributedContent")
        }
    }
}

// MARK: - Inline popover view (kept inside ToolbarView.swift)
private struct FontStylePopover: View {
    @Binding var isPresented: Bool
    @Binding var bold: Bool
    @Binding var italic: Bool
    @Binding var underline: Bool
    @Binding var strikethrough: Bool
    var applyToSelection: () -> Void
    var setForTyping: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Font Style").font(.headline)
            HStack(spacing: 12) {
                Toggle("Bold", isOn: $bold)
                Toggle("Italic", isOn: $italic)
            }
            HStack(spacing: 12) {
                Toggle("Underline", isOn: $underline)
                Toggle("Strikethrough", isOn: $strikethrough)
            }
            HStack {
                Button("Apply to Selection") {
                    applyToSelection()
                }
                Spacer()
                Button("Set for Future Typing") {
                    setForTyping()
                }
            }
        }
    }
}
