import Foundation
import Combine
import SwiftUI

/// Manages theme selection for the app.
///
/// Themes can be provided either by the built‑in list (`Theme.builtInThemes`) or
/// via JSON files stored in the app’s asset catalog. The manager first attempts to
/// load a custom theme from the bundle; if that fails it falls back to the
/// built‑in collection.
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    /// The currently active theme. Published so UI can react to changes.
    @Published var currentTheme: Theme

    // Use the same UserDefaults key as the Preferences UI so changes are reflected
    private let currentThemeKey = "app.theme"

    private init() {
        // Default to the first built‑in theme while we resolve any persisted
        // custom theme.
        currentTheme = Theme.builtInThemes[0]

        // Resolve the persisted theme identifier.
        let storedId = UserDefaults.standard.string(forKey: currentThemeKey) ?? "xcode-light"
        // Try loading a custom theme from the asset catalog first.
        if let custom = loadThemeFromAssets(id: storedId) {
            currentTheme = custom
        } else if let builtin = Theme.builtInThemes.first(where: { $0.id == storedId }) {
            currentTheme = builtin
        }
    }

    /// Returns all available themes – built‑in plus any custom JSON files found
    /// in the asset catalog.
    var allThemes: [Theme] {
        // Load custom themes from the bundle (if any) and combine with built‑ins.
        let custom = loadAllCustomThemes()
        return custom + Theme.builtInThemes
    }

    /// Sets the active theme and persists its identifier.
    func setTheme(_ theme: Theme) {
        currentTheme = theme
        UserDefaults.standard.set(theme.id, forKey: currentThemeKey)
    }

    // MARK: - Asset catalog helpers

    /// Attempts to load a `Theme` JSON file from the app bundle using the given
    /// identifier. The JSON should match the `Theme` structure.
    private func loadThemeFromAssets(id: String) -> Theme? {
        guard let url = Bundle.main.url(forResource: id, withExtension: "json") else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(Theme.self, from: data)
        } catch {
            print("[ThemeManager] Failed to load theme '\(id)' from assets: \(error)")
            return nil
        }
    }

    /// Loads every JSON file in the main bundle that matches the pattern
    /// `*.theme.json` (convention used for custom themes). Returns an empty array
    /// if none are found.
    private func loadAllCustomThemes() -> [Theme] {
        guard let urls = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil) else { return [] }
        var themes: [Theme] = []
        for url in urls {
            // Only consider files that are intended as themes – they should be
            // named exactly like the theme id (e.g., "my‑custom.theme.json").
            // The simple heuristic is to attempt decoding; failures are ignored.
            if let data = try? Data(contentsOf: url),
               let theme = try? JSONDecoder().decode(Theme.self, from: data) {
                themes.append(theme)
            }
        }
        return themes
    }
}

