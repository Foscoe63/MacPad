import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct FileMenuCommands: Commands {
    private var appState: AppState { AppState.shared }

    var body: some Commands {
        // Replace the default New/Open items under the system File menu
        CommandGroup(replacing: .newItem) {
            Button("New", action: { appState.newDocument() })
                .keyboardShortcut("n", modifiers: .command)
            Button("Open…", action: { appState.openPanel() })
                .keyboardShortcut("o", modifiers: .command)
        }

        // Replace the default Save items under the same File menu
        CommandGroup(replacing: .saveItem) {
            Button("Save", action: { appState.saveCurrent() })
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState.getDocument(id: appState.selectedTab)?.isModified != true)
            Button("Save As…", action: { appState.saveAsCurrent() })
                .keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(appState.getDocument(id: appState.selectedTab) == nil)
            Button("Save All", action: { appState.saveAll() })
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(appState.documents.isEmpty)
        }

        // Add Close Tab after the Save group within the File menu
        CommandGroup(after: .saveItem) {
            Divider()
            Button("Close Tab", action: { appState.closeCurrent() })
                .keyboardShortcut("w", modifiers: .command)
                .disabled(appState.documents.isEmpty)
        }
        
        // Add Quick Open command
        CommandGroup(after: .newItem) {
            Button("Quick Open…", action: {
                NotificationCenter.default.post(name: .mpQuickOpen, object: nil)
            })
            .keyboardShortcut("p", modifiers: .command)
        }
        
        // Add Go to Line command
        CommandGroup(after: .newItem) {
            Button("Go to Line…", action: {
                NotificationCenter.default.post(name: .mpGoToLine, object: nil)
            })
            .keyboardShortcut("g", modifiers: .command)
        }
    }
}
