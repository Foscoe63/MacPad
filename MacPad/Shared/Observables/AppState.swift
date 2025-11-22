import Foundation
import SwiftUI
import Combine
import AppKit
import UniformTypeIdentifiers

class AppState: ObservableObject {
    // Shared instance so Commands and App-level handlers can reach the same state
    static let shared = AppState()

    @Published var documents: [Document] = [
        Document(name: "Untitled", content: "", path: nil, syntaxMode: .swift)
    ]
    
    @Published var selectedTab: UUID = UUID()
    
    private let sessionKey = "session.openDocuments.v1"
    private let sessionSelectedIndexKey = "session.selectedIndex.v1"
    
    init() {
        selectedTab = documents.first?.id ?? UUID()
        // Attempt to restore previous session (unsaved docs) if enabled by user
        restoreSessionIfEnabled()
    }
    
    func addDocument(name: String = "Untitled", content: String = "", path: URL? = nil, syntaxMode: SyntaxMode = .swift, attributedContent: NSAttributedString? = nil) {
        let newDoc = Document(name: name, content: content, path: path, syntaxMode: syntaxMode, attributedContent: attributedContent)
        documents.append(newDoc)
        selectedTab = newDoc.id
    }
    
    func removeDocument(id: UUID) {
        guard let idx = documents.firstIndex(where: { $0.id == id }) else { return }
        documents.remove(at: idx)
        if documents.isEmpty {
            let newDoc = Document(name: "Untitled", content: "", path: nil, syntaxMode: .swift)
            documents = [newDoc]
            selectedTab = newDoc.id
        } else {
            let newIndex = min(idx, documents.count - 1)
            selectedTab = documents[newIndex].id
        }
    }
    
    func getDocument(id: UUID) -> Document? {
        documents.first { $0.id == id }
    }
    
    func moveDocument(from source: IndexSet, to destination: Int) {
        documents.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - File open helpers (Finder/Dock + Menu)
    func open(urls: [URL]) {
        // Avoid opening the same file in multiple tabs. If already open, focus it.
        for url in urls {
            let target = url.standardizedFileURL
            if let existing = documents.first(where: { $0.path?.standardizedFileURL == target }) {
                selectedTab = existing.id
                continue
            }
            let (attr, plain) = Self.loadRichIfAvailable(from: target)
            let syntax = SyntaxMode.from(path: target) ?? .swift
            addDocument(name: target.lastPathComponent, content: plain, path: target, syntaxMode: syntax, attributedContent: attr)
        }
    }

    func openPanel() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.plainText, .rtf, .html]
        if panel.runModal() == .OK {
            open(urls: panel.urls)
        }
    }

    // MARK: - File save helpers (Menu + Close prompts)
    func newDocument() {
        addDocument(name: "Untitled", content: "", path: nil, syntaxMode: .swift, attributedContent: nil)
    }

    func saveCurrent() {
        guard let doc = getDocument(id: selectedTab) else { return }
        _ = save(document: doc)
    }

    func saveAsCurrent() {
        guard let doc = getDocument(id: selectedTab) else { return }
        _ = saveAs(document: doc)
    }

    func saveAll() {
        for doc in documents {
            _ = save(document: doc)
        }
    }

    func closeCurrent() {
        guard let doc = getDocument(id: selectedTab) else { return }
        if doc.isModified {
            let alert = NSAlert()
            alert.messageText = "Do you want to save the changes made to \(doc.name)?"
            alert.informativeText = "Your changes will be lost if you don’t save them."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Don’t Save")
            alert.addButton(withTitle: "Cancel")
            let response = alert.runModal()
            switch response {
            case .alertFirstButtonReturn:
                if save(document: doc) { removeDocument(id: doc.id) }
            case .alertSecondButtonReturn:
                removeDocument(id: doc.id)
            default:
                break
            }
        } else {
            removeDocument(id: doc.id)
        }
    }

    @discardableResult
    private func save(document: Document) -> Bool {
        if let url = document.path {
            let ext = url.pathExtension.lowercased()
            let type: UTType
            switch ext {
            case "rtf": type = .rtf
            case "html", "htm": type = .html
            default: type = .plainText
            }
            do {
                try write(document, to: url, as: type)
                document.isModified = false
                return true
            } catch {
                let alert = NSAlert()
                alert.messageText = "Failed to Save"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
                return false
            }
        } else {
            return saveAs(document: document)
        }
    }

    @discardableResult
    private func saveAs(document: Document) -> Bool {
        guard let result = SavePanelHelper.presentSavePanel(suggestedName: document.name, initialURL: document.path) else { return false }
        do {
            try write(document, to: result.url, as: result.type)
            document.path = result.url
            document.name = result.url.lastPathComponent
            document.isModified = false
            return true
        } catch {
            let alert = NSAlert()
            alert.messageText = "Failed to Save"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return false
        }
    }

    private func focusedTextView() -> NSTextView? {
        NSApp.keyWindow?.firstResponder as? NSTextView
    }

    private func write(_ doc: Document, to url: URL, as type: UTType) throws {
        if type == .plainText {
            try doc.content.write(to: url, atomically: true, encoding: .utf8)
            return
        }
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
                try doc.content.write(to: url, atomically: true, encoding: .utf8)
            }
        } else {
            try doc.content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // Unified rich loader for RTF/HTML
    private static func loadRichIfAvailable(from url: URL) -> (NSAttributedString?, String) {
        let ext = url.pathExtension.lowercased()
        if ext == "rtf" || ext == "rtfd" {
            if let attr = try? NSAttributedString(url: url, options: [:], documentAttributes: nil) {
                return (attr, attr.string)
            }
        } else if ext == "html" || ext == "htm" {
            let folder = url.deletingLastPathComponent()
            if let data = try? Data(contentsOf: url) {
                // Try to obtain an HTML string (UTF-8 preferred) for CSS inlining and color detection
                let htmlString: String? = String(data: data, encoding: .utf8) ?? (String(data: data, encoding: .isoLatin1))
                let inlinedHTML: String
                if let html = htmlString {
                    inlinedHTML = inlineExternalCSS(in: html, baseURL: folder)
                } else {
                    // If we cannot decode safely, fall back to original data import
                    inlinedHTML = String(data: data, encoding: .utf8) ?? ""
                }

                let baseOptions: [NSAttributedString.DocumentReadingOptionKey: Any] = [
                    .documentType: NSAttributedString.DocumentType.html,
                    .characterEncoding: String.Encoding.utf8.rawValue,
                    .baseURL: folder
                ]

                func hasForegroundColors(_ s: NSAttributedString) -> Bool {
                    guard s.length > 0 else { return false }
                    var found = false
                    let full = NSRange(location: 0, length: s.length)
                    s.enumerateAttribute(.foregroundColor, in: full, options: []) { value, _, stop in
                        if value != nil { found = true; stop.pointee = true }
                    }
                    return found
                }

                // Detect a global/default color from <body style> or CSS (e.g., body { color: … })
                // Detect default color against the INLINED HTML (so external CSS is considered)
                let detectedDefaultColor: NSColor? = {
                    let htmlForDetection: String
                    if !inlinedHTML.isEmpty {
                        htmlForDetection = inlinedHTML
                    } else if let html = htmlString {
                        htmlForDetection = html
                    } else {
                        return nil
                    }
                    return detectBodyTextColor(in: htmlForDetection, baseURL: folder)
                }()

                // Prepare data to import (prefer inlined CSS when available)
                let importData: Data
                if let d = inlinedHTML.data(using: .utf8), !inlinedHTML.isEmpty {
                    importData = d
                } else {
                    importData = data
                }

                // First attempt
                if let first = try? NSAttributedString(data: importData, options: baseOptions, documentAttributes: nil) {
                    // DEBUG: log color runs after import
                    let firstHasColors = hasForegroundColors(first)
                    if firstHasColors {
                        print("[HTML Import] First pass produced foreground colors for \(url.lastPathComponent)")
                        return (first, first.string)
                    } else {
                        print("[HTML Import] First pass NO color runs for \(url.lastPathComponent)")
                    }
                    // Second attempt: provide defaultAttributes if we detected a default color
                    if let bodyColor = detectedDefaultColor {
                        var retryOptions = baseOptions
                        retryOptions[.defaultAttributes] = [NSAttributedString.Key.foregroundColor: bodyColor]
                        if let second = try? NSAttributedString(data: importData, options: retryOptions, documentAttributes: nil) {
                            let secondHasColors = hasForegroundColors(second)
                            if secondHasColors {
                                print("[HTML Import] Second pass (with body color default) produced colors for \(url.lastPathComponent)")
                                return (second, second.string)
                            } else {
                                print("[HTML Import] Second pass still NO color runs for \(url.lastPathComponent); applying body color across full range")
                                // As a last resort, apply body color across the full range if importer didn’t create runs
                                let mutable = NSMutableAttributedString(attributedString: second)
                                let full = NSRange(location: 0, length: mutable.length)
                                if full.length > 0 {
                                    mutable.addAttribute(.foregroundColor, value: bodyColor, range: full)
                                }
                                return (mutable, mutable.string)
                            }
                        }
                    }
                    // Third attempt (previous fallback): explicit empty defaults
                    var fallbackOptions = baseOptions
                    fallbackOptions[.defaultAttributes] = [:]
                    if let third = try? NSAttributedString(data: importData, options: fallbackOptions, documentAttributes: nil) {
                        let thirdHasColors = hasForegroundColors(third)
                        print("[HTML Import] Third pass (empty defaults) hasColors=\(thirdHasColors) for \(url.lastPathComponent)")
                        return (third, third.string)
                    }
                }
            }
        }
        // Fallback plain loader
        if let txt = try? String(contentsOf: url, encoding: .utf8) {
            return (nil, txt)
        } else if let data = try? Data(contentsOf: url), let txt = String(data: data, encoding: .utf8) {
            return (nil, txt)
        }
        return (nil, "")
    }

    // MARK: - HTML helpers
    // CSS inliner: collects styles from <link rel="stylesheet" ... href=...> tags (any order, single/double/no quotes)
    // and injects a single <style> block into <head>. Also inlines one-level @import rules inside those CSS files.
    private static func inlineExternalCSS(in html: String, baseURL: URL) -> String {
        guard html.range(of: "<link", options: .caseInsensitive) != nil else { return html }
        let ns = html as NSString
        var cssBundle = ""

        // 1) Find all <link ...> tags
        let linkPattern = "<link[^>]*>"
        if let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: [.caseInsensitive]) {
            let matches = linkRegex.matches(in: html, options: [], range: NSRange(location: 0, length: ns.length))
            for m in matches {
                let tag = ns.substring(with: m.range)
                // Must contain rel=stylesheet (any quotes)
                let relIsStylesheet: Bool = {
                    let relPattern = #"rel\s*=\s*(?:"stylesheet"|'stylesheet'|stylesheet)"#
                    return (try? NSRegularExpression(pattern: relPattern, options: [.caseInsensitive]))?.firstMatch(in: tag, options: [], range: NSRange(location: 0, length: (tag as NSString).length)) != nil
                }()
                guard relIsStylesheet else { continue }
                // Extract href value (single/double/no quote)
                let hrefPattern = #"href\s*=\s*(?:"([^"]+)"|'([^']+)'|([^\s>]+))"#
                if let hrefRegex = try? NSRegularExpression(pattern: hrefPattern, options: [.caseInsensitive]),
                   let hm = hrefRegex.firstMatch(in: tag, options: [], range: NSRange(location: 0, length: (tag as NSString).length)) {
                    let tns = tag as NSString
                    var href: String? = nil
                    for i in 1...3 {
                        let r = hm.range(at: i)
                        if r.location != NSNotFound {
                            href = tns.substring(with: r)
                            break
                        }
                    }
                    if let href = href {
                        let resolved: URL = {
                            if let abs = URL(string: href), abs.scheme != nil { return abs }
                            return baseURL.appendingPathComponent(href)
                        }()
                        if let cssData = try? Data(contentsOf: resolved),
                           var cssText = String(data: cssData, encoding: .utf8) ?? String(data: cssData, encoding: .isoLatin1) {
                            // Inline one-level @import rules inside CSS
                            cssText = inlineCSSImports(in: cssText, baseURL: resolved.deletingLastPathComponent())
                            cssBundle.append("\n/* Inlined: \(href) */\n")
                            cssBundle.append(cssText)
                            cssBundle.append("\n")
                        }
                    }
                }
            }
        }
        guard !cssBundle.isEmpty else { return html }

        // 2) Inject CSS into <head>; if no head, prepend
        let styleTag = "<style>\n\(cssBundle)\n</style>"
        if let headRange = html.range(of: "</head>", options: .caseInsensitive) {
            var result = html
            result.replaceSubrange(headRange, with: styleTag + "\n</head>")
            return result
        } else {
            return styleTag + html
        }
    }

    // Inline one-level @import statements inside a CSS string
    private static func inlineCSSImports(in css: String, baseURL: URL) -> String {
        var result = css
        // Match @import url('...'); (single-level)
        let pattern = "@import\\s+url\\(\\s*['\\\"]?([^\\)\\\"']+)['\\\"]?\\s*\\)\\s*;"
        if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
            let ns = result as NSString
            let matches = regex.matches(in: result, options: [], range: NSRange(location: 0, length: ns.length)).reversed()
            for m in matches {
                // capture group 1 contains the URL per our simplified pattern
                let href = ns.substring(with: m.range(at: 1))
                let resolved: URL = {
                    if let abs = URL(string: href), abs.scheme != nil { return abs }
                    return baseURL.appendingPathComponent(href)
                }()
                if let data = try? Data(contentsOf: resolved), let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) {
                    result = (result as NSString).replacingCharacters(in: m.range, with: "/* Inlined import: \(href) */\n" + text)
                }
            }
        }
        return result
    }

    // Extract a global/body text color from inline <body style> or CSS body { color: … }
    private static func detectBodyTextColor(in html: String, baseURL: URL) -> NSColor? {
        // 1) Inline <body style="color: ...">
        if let colorString = matchFirst(in: html, pattern: "<body[^>]*?style=\\\"[^\\\"]*?color\\s*:\\s*([^;\\\"]+)" , options: [.caseInsensitive]) {
            if let c = parseColor(fromCSS: colorString.trimmingCharacters(in: .whitespacesAndNewlines)) { return c }
        }
        // 2) CSS body { color: ... }
        if let colorString = matchFirst(in: html, pattern: "body\\s*\\{[^}]*?color\\s*:\\s*([^;\\}]+)", options: [.caseInsensitive]) {
            if let c = parseColor(fromCSS: colorString.trimmingCharacters(in: .whitespacesAndNewlines)) { return c }
        }
        return nil
    }

    private static func matchFirst(in text: String, pattern: String, options: NSRegularExpression.Options = []) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let ns = text as NSString
        if let m = regex.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)), m.numberOfRanges >= 2 {
            return ns.substring(with: m.range(at: 1))
        }
        return nil
    }

    // Minimal CSS color parser: supports #RGB, #RRGGBB, rgb(), rgba(), and a few common names
    private static func parseColor(fromCSS cssValue: String) -> NSColor? {
        let v = cssValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        // Named colors (minimal set)
        let named: [String: NSColor] = [
            "black": .black,
            "white": .white,
            "red": .red,
            "green": .green,
            "blue": .blue,
            "gray": .gray,
            "grey": .gray,
            "yellow": .yellow,
            "magenta": .magenta,
            "cyan": .cyan
        ]
        if let c = named[v] { return c }
        // Hex #RRGGBB or #RGB
        if v.hasPrefix("#") {
            let hex = String(v.dropFirst())
            if hex.count == 6, let num = Int(hex, radix: 16) {
                let r = CGFloat((num >> 16) & 0xFF) / 255.0
                let g = CGFloat((num >> 8) & 0xFF) / 255.0
                let b = CGFloat(num & 0xFF) / 255.0
                return NSColor(calibratedRed: r, green: g, blue: b, alpha: 1.0)
            } else if hex.count == 3 {
                let r = String(repeating: String(hex[hex.startIndex]), count: 2)
                let g = String(repeating: String(hex[hex.index(hex.startIndex, offsetBy: 1)]), count: 2)
                let b = String(repeating: String(hex[hex.index(hex.startIndex, offsetBy: 2)]), count: 2)
                if let num = Int(r+g+b, radix: 16) {
                    let rr = CGFloat((num >> 16) & 0xFF) / 255.0
                    let gg = CGFloat((num >> 8) & 0xFF) / 255.0
                    let bb = CGFloat(num & 0xFF) / 255.0
                    return NSColor(calibratedRed: rr, green: gg, blue: bb, alpha: 1.0)
                }
            }
        }
        // rgb()/rgba()
        if v.hasPrefix("rgb") {
            let numbers = v.replacingOccurrences(of: "rgba", with: "rgb")
                .replacingOccurrences(of: "rgb", with: "")
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
            let parts = numbers.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count >= 3 {
                func parseComponent(_ s: String) -> CGFloat? {
                    if s.hasSuffix("%") {
                        let val = Double(s.dropLast()) ?? 0
                        return CGFloat(max(0, min(100, val)) / 100.0)
                    } else {
                        let val = Double(s) ?? 0
                        return CGFloat(max(0, min(255, val)) / 255.0)
                    }
                }
                if let r = parseComponent(parts[0]), let g = parseComponent(parts[1]), let b = parseComponent(parts[2]) {
                    let a: CGFloat
                    if parts.count >= 4 { a = CGFloat(Double(parts[3]) ?? 1.0) } else { a = 1.0 }
                    return NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
                }
            }
        }
        return nil
    }
    
    // MARK: - Session Persistence
    private struct SessionDoc: Codable {
        var name: String
        var content: String
        var path: String?
        var syntax: SyntaxMode
        var isModified: Bool
    }
    
    func saveSessionIfEnabled() {
        let enabled = UserDefaults.standard.object(forKey: "editor.restoreUnsavedOnLaunch") as? Bool ?? true
        guard enabled else { return }
        // Snapshot current open documents
        let payload: [SessionDoc] = documents.map { doc in
            SessionDoc(
                name: doc.name,
                content: doc.content,
                path: doc.path?.path,
                syntax: doc.syntaxMode,
                isModified: doc.isModified
            )
        }
        do {
            let data = try JSONEncoder().encode(payload)
            let defaults = UserDefaults.standard
            defaults.set(data, forKey: sessionKey)
            if let index = documents.firstIndex(where: { $0.id == selectedTab }) {
                defaults.set(index, forKey: sessionSelectedIndexKey)
            }
            // Best-effort flush to disk to reduce chance of data loss on sudden quit
            _ = defaults.synchronize()
        } catch {
            // Ignore serialization errors
        }
    }
    
    func restoreSessionIfEnabled() {
        let enabled = UserDefaults.standard.object(forKey: "editor.restoreUnsavedOnLaunch") as? Bool ?? true
        guard enabled else { return }
        guard let data = UserDefaults.standard.data(forKey: sessionKey) else { return }
        do {
            let payload = try JSONDecoder().decode([SessionDoc].self, from: data)
            guard !payload.isEmpty else { return }
            // Replace current docs with restored ones
            var restored: [Document] = []
            for sd in payload {
                let url = sd.path.flatMap { URL(fileURLWithPath: $0) }
                let doc = Document(name: sd.name, content: sd.content, path: url, syntaxMode: sd.syntax)
                // If the file on disk is a rich text format we can load attributes now to restore colors
                if let url = url {
                    let (attr, plain) = Self.loadRichIfAvailable(from: url)
                    if let attr = attr {
                        doc.attributedContent = attr
                        doc.content = attr.string
                    } else {
                        doc.content = plain
                    }
                }
                doc.isModified = sd.isModified
                restored.append(doc)
            }
            if !restored.isEmpty {
                documents = restored
                // Restore selected index
                let selIdx = UserDefaults.standard.integer(forKey: sessionSelectedIndexKey)
                let clamped = max(0, min(selIdx, documents.count - 1))
                selectedTab = documents[clamped].id
            }
        } catch {
            // Ignore deserialization errors
        }
    }
}