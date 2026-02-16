import AppKit
import UniformTypeIdentifiers
import ObjectiveC.runtime

// Association key to retain popup target during the save panel lifetime
private var SavePanelPopupSleeveKey: UInt8 = 0

enum SaveFormat: Int, CaseIterable {
    case txt = 0
    case rtf = 1
    case html = 2

    var title: String {
        switch self {
        case .txt: return "Plain Text (.txt)"
        case .rtf: return "Rich Text (.rtf)"
        case .html: return "HTML (.html)"
        }
    }
    var utType: UTType {
        switch self {
        case .txt: return .plainText
        case .rtf: return .rtf
        case .html: return .html
        }
    }
    var fileExtension: String {
        switch self {
        case .txt: return "txt"
        case .rtf: return "rtf"
        case .html: return "html"
        }
    }

    static func from(fileExtension ext: String) -> SaveFormat? {
        switch ext.lowercased() {
        case "txt": return .txt
        case "rtf": return .rtf
        case "html", "htm": return .html
        default: return nil
        }
    }
}

struct SavePanelHelper {
    static func presentSavePanel(suggestedName: String, initialURL: URL?) -> (url: URL, type: UTType)? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedName
        if let dir = initialURL?.deletingLastPathComponent() {
            panel.directoryURL = dir
        }
        panel.allowedContentTypes = [.plainText, .rtf, .html]

        // Determine default format
        let defaults = UserDefaults.standard
        let last = defaults.integer(forKey: "save.lastFormat")
        let suggestedExt = URL(fileURLWithPath: suggestedName).pathExtension
        let defaultFormat: SaveFormat = SaveFormat.from(fileExtension: suggestedExt)
            ?? SaveFormat(rawValue: last)
            ?? .txt

        // Build accessory view
        let accessory = NSView(frame: NSRect(x: 0, y: 0, width: 320, height: 30))
        let label = NSTextField(labelWithString: "Format:")
        label.frame = NSRect(x: 0, y: 6, width: 60, height: 18)
        let popup = NSPopUpButton(frame: NSRect(x: 66, y: 2, width: 240, height: 24))
        for f in SaveFormat.allCases { popup.addItem(withTitle: f.title) }
        popup.selectItem(at: defaultFormat.rawValue)
        accessory.addSubview(label)
        accessory.addSubview(popup)
        panel.accessoryView = accessory

        // Keep filename extension in sync with popup selection while panel is open
        let sleeve = ClosureSleeve(action: { [unowned panel] in
            let selected = SaveFormat(rawValue: popup.indexOfSelectedItem) ?? .txt
            let current = panel.nameFieldStringValue
            let base = (current as NSString).deletingPathExtension
            panel.nameFieldStringValue = base + "." + selected.fileExtension
        })
        popup.target = sleeve
        popup.action = #selector(ClosureSleeve.invoke)
        // Retain the sleeve for the lifetime of the popup/panel to avoid target deallocation
        objc_setAssociatedObject(popup, &SavePanelPopupSleeveKey, sleeve, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        // Initialize name field to include correct extension
        do {
            let selected = defaultFormat
            let base = (panel.nameFieldStringValue as NSString).deletingPathExtension
            panel.nameFieldStringValue = base + "." + selected.fileExtension
        }

        let response = panel.runModal()
        guard response == .OK, let chosenURL = panel.url else { return nil }
        let selected = SaveFormat(rawValue: popup.indexOfSelectedItem) ?? .txt
        defaults.set(selected.rawValue, forKey: "save.lastFormat")
        defaults.synchronize()

        // Coerce URL to chosen extension if necessary
        var finalURL = chosenURL
        let ext = chosenURL.pathExtension.lowercased()
        if SaveFormat.from(fileExtension: ext) != selected {
            let noExt = chosenURL.deletingPathExtension()
            finalURL = noExt.appendingPathExtension(selected.fileExtension)
        }
        return (finalURL, selected.utType)
    }
}

// Utility to attach closures to Cocoa controls without subclassing
private final class ClosureSleeve: NSObject {
    private let _action: () -> Void
    init(action: @escaping () -> Void) { self._action = action }
    @objc func invoke() { _action() }
}
