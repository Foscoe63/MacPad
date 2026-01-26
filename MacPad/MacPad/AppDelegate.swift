import SwiftUI
import AppKit

@main
struct NewTextApp: App {
    @NSApplicationDelegateAdaptor(AppKitDelegate.self) var appDelegate

    init() {
        // Register defaults to ensure stable preferences across launches
        UserDefaults.standard.register(defaults: [
            "application.textMode": "plain",
            "prefs.selectedPane": PreferencesPane.application.rawValue,
            // File Browser font defaults
            "browser.fontDesign": "system",   // system | monospaced
            "browser.fontSize": 13.0,
            "browser.sortOrder": "name",       // name, type, date, size
            // Editor defaults
            "editor.goToDefinition": true,
            "editor.wordWrap": true,
            "tabs.draggable": true,
            // Advanced defaults
            "advanced.linting": true
        ])
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            FileMenuCommands()
            EditMenuCommands()
        }
        Settings {
            PreferencesRootView()
        }
    }
}

// MARK: - NSApplication Delegate to handle Finder "Open With" and drops on Dock
final class AppKitDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        // Open immediately (works for cold start) and also post for any listeners
        AppState.shared.open(urls: urls)
        NotificationCenter.default.post(name: .mpOpenFiles, object: nil, userInfo: ["urls": urls])
        NSApp.activate(ignoringOtherApps: true)
    }
}