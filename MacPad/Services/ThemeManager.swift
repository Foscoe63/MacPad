import Foundation
import Combine
import SwiftUI

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentTheme: Theme
    
    private let currentThemeKey = "currentThemeId"
    
    private init() {
        // Initialize with default theme
        currentTheme = Theme.builtInThemes[0]
        
        // Load current theme
        let themeId = UserDefaults.standard.string(forKey: currentThemeKey) ?? "xcode-light"
        if let theme = Theme.builtInThemes.first(where: { $0.id == themeId }) {
            currentTheme = theme
        }
    }
    
    var allThemes: [Theme] {
        Theme.builtInThemes
    }
    
    func setTheme(_ theme: Theme) {
        guard theme.isBuiltIn else { return } // Only allow built-in themes
        currentTheme = theme
        UserDefaults.standard.set(currentTheme.id, forKey: currentThemeKey)
    }
}

