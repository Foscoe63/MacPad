import SwiftUI
import AppKit

@main
struct NewTextApp: App {
    @NSApplicationDelegateAdaptor(AppKitDelegate.self) var appDelegate

    init() {
        // Register defaults to ensure stable preferences across launches
        UserDefaults.standard.register(defaults: [
            "application.textMode": "plain",
            "prefs.selectedPane": PreferencesPane.application.rawValue
        ])
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            FileMenuCommands()
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