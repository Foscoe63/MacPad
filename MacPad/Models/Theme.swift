import Foundation
import SwiftUI

struct Theme: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    let isBuiltIn: Bool
    
    // Color definitions
    var background: ThemeColor
    var foreground: ThemeColor
    var selection: ThemeColor
    var comment: ThemeColor
    var keyword: ThemeColor
    var string: ThemeColor
    var number: ThemeColor
    var function: ThemeColor
    var variable: ThemeColor
    var type: ThemeColor
    
    static let builtInThemes: [Theme] = [
        // Xcode Light
        Theme(
            id: "xcode-light",
            name: "Xcode Light",
            isBuiltIn: true,
            background: ThemeColor(light: "#FFFFFF", dark: "#FFFFFF"),
            foreground: ThemeColor(light: "#000000", dark: "#000000"),
            selection: ThemeColor(light: "#B3D7FF", dark: "#B3D7FF"),
            comment: ThemeColor(light: "#007400", dark: "#007400"),
            keyword: ThemeColor(light: "#0033B3", dark: "#0033B3"),
            string: ThemeColor(light: "#C41A16", dark: "#C41A16"),
            number: ThemeColor(light: "#1750EB", dark: "#1750EB"),
            function: ThemeColor(light: "#00627A", dark: "#00627A"),
            variable: ThemeColor(light: "#000000", dark: "#000000"),
            type: ThemeColor(light: "#267F99", dark: "#267F99")
        ),
        // Xcode Dark
        Theme(
            id: "xcode-dark",
            name: "Xcode Dark",
            isBuiltIn: true,
            background: ThemeColor(light: "#1F1F24", dark: "#1F1F24"),
            foreground: ThemeColor(light: "#DEDEDE", dark: "#DEDEDE"),
            selection: ThemeColor(light: "#264F78", dark: "#264F78"),
            comment: ThemeColor(light: "#6A9955", dark: "#6A9955"),
            keyword: ThemeColor(light: "#569CD6", dark: "#569CD6"),
            string: ThemeColor(light: "#CE9178", dark: "#CE9178"),
            number: ThemeColor(light: "#B5CEA8", dark: "#B5CEA8"),
            function: ThemeColor(light: "#DCDCAA", dark: "#DCDCAA"),
            variable: ThemeColor(light: "#9CDCFE", dark: "#9CDCFE"),
            type: ThemeColor(light: "#4EC9B0", dark: "#4EC9B0")
        ),
        // VS Code Dark+
        Theme(
            id: "vscode-dark",
            name: "VS Code Dark+",
            isBuiltIn: true,
            background: ThemeColor(light: "#1E1E1E", dark: "#1E1E1E"),
            foreground: ThemeColor(light: "#D4D4D4", dark: "#D4D4D4"),
            selection: ThemeColor(light: "#264F78", dark: "#264F78"),
            comment: ThemeColor(light: "#6A9955", dark: "#6A9955"),
            keyword: ThemeColor(light: "#569CD6", dark: "#569CD6"),
            string: ThemeColor(light: "#CE9178", dark: "#CE9178"),
            number: ThemeColor(light: "#B5CEA8", dark: "#B5CEA8"),
            function: ThemeColor(light: "#DCDCAA", dark: "#DCDCAA"),
            variable: ThemeColor(light: "#9CDCFE", dark: "#9CDCFE"),
            type: ThemeColor(light: "#4EC9B0", dark: "#4EC9B0")
        ),
        // VS Code Light+
        Theme(
            id: "vscode-light",
            name: "VS Code Light+",
            isBuiltIn: true,
            background: ThemeColor(light: "#FFFFFF", dark: "#FFFFFF"),
            foreground: ThemeColor(light: "#000000", dark: "#000000"),
            selection: ThemeColor(light: "#ADD6FF", dark: "#ADD6FF"),
            comment: ThemeColor(light: "#008000", dark: "#008000"),
            keyword: ThemeColor(light: "#0000FF", dark: "#0000FF"),
            string: ThemeColor(light: "#A31515", dark: "#A31515"),
            number: ThemeColor(light: "#098658", dark: "#098658"),
            function: ThemeColor(light: "#795E26", dark: "#795E26"),
            variable: ThemeColor(light: "#001080", dark: "#001080"),
            type: ThemeColor(light: "#267F99", dark: "#267F99")
        ),
        // Monokai
        Theme(
            id: "monokai",
            name: "Monokai",
            isBuiltIn: true,
            background: ThemeColor(light: "#272822", dark: "#272822"),
            foreground: ThemeColor(light: "#F8F8F2", dark: "#F8F8F2"),
            selection: ThemeColor(light: "#49483E", dark: "#49483E"),
            comment: ThemeColor(light: "#75715E", dark: "#75715E"),
            keyword: ThemeColor(light: "#F92672", dark: "#F92672"),
            string: ThemeColor(light: "#E6DB74", dark: "#E6DB74"),
            number: ThemeColor(light: "#AE81FF", dark: "#AE81FF"),
            function: ThemeColor(light: "#A6E22E", dark: "#A6E22E"),
            variable: ThemeColor(light: "#F8F8F2", dark: "#F8F8F2"),
            type: ThemeColor(light: "#66D9EF", dark: "#66D9EF")
        ),
        // Solarized Dark
        Theme(
            id: "solarized-dark",
            name: "Solarized Dark",
            isBuiltIn: true,
            background: ThemeColor(light: "#002B36", dark: "#002B36"),
            foreground: ThemeColor(light: "#839496", dark: "#839496"),
            selection: ThemeColor(light: "#073642", dark: "#073642"),
            comment: ThemeColor(light: "#586E75", dark: "#586E75"),
            keyword: ThemeColor(light: "#859900", dark: "#859900"),
            string: ThemeColor(light: "#2AA198", dark: "#2AA198"),
            number: ThemeColor(light: "#D33682", dark: "#D33682"),
            function: ThemeColor(light: "#268BD2", dark: "#268BD2"),
            variable: ThemeColor(light: "#839496", dark: "#839496"),
            type: ThemeColor(light: "#B58900", dark: "#B58900")
        ),
        // Solarized Light
        Theme(
            id: "solarized-light",
            name: "Solarized Light",
            isBuiltIn: true,
            background: ThemeColor(light: "#FDF6E3", dark: "#FDF6E3"),
            foreground: ThemeColor(light: "#657B83", dark: "#657B83"),
            selection: ThemeColor(light: "#EEE8D5", dark: "#EEE8D5"),
            comment: ThemeColor(light: "#93A1A1", dark: "#93A1A1"),
            keyword: ThemeColor(light: "#859900", dark: "#859900"),
            string: ThemeColor(light: "#2AA198", dark: "#2AA198"),
            number: ThemeColor(light: "#D33682", dark: "#D33682"),
            function: ThemeColor(light: "#268BD2", dark: "#268BD2"),
            variable: ThemeColor(light: "#657B83", dark: "#657B83"),
            type: ThemeColor(light: "#B58900", dark: "#B58900")
        ),
        // GitHub Dark
        Theme(
            id: "github-dark",
            name: "GitHub Dark",
            isBuiltIn: true,
            background: ThemeColor(light: "#0D1117", dark: "#0D1117"),
            foreground: ThemeColor(light: "#C9D1D9", dark: "#C9D1D9"),
            selection: ThemeColor(light: "#264F78", dark: "#264F78"),
            comment: ThemeColor(light: "#8B949E", dark: "#8B949E"),
            keyword: ThemeColor(light: "#FF7B72", dark: "#FF7B72"),
            string: ThemeColor(light: "#A5D6FF", dark: "#A5D6FF"),
            number: ThemeColor(light: "#79C0FF", dark: "#79C0FF"),
            function: ThemeColor(light: "#D2A8FF", dark: "#D2A8FF"),
            variable: ThemeColor(light: "#C9D1D9", dark: "#C9D1D9"),
            type: ThemeColor(light: "#79C0FF", dark: "#79C0FF")
        ),
        // GitHub Light
        Theme(
            id: "github-light",
            name: "GitHub Light",
            isBuiltIn: true,
            background: ThemeColor(light: "#FFFFFF", dark: "#FFFFFF"),
            foreground: ThemeColor(light: "#24292F", dark: "#24292F"),
            selection: ThemeColor(light: "#B6E3FF", dark: "#B6E3FF"),
            comment: ThemeColor(light: "#6E7781", dark: "#6E7781"),
            keyword: ThemeColor(light: "#CF222E", dark: "#CF222E"),
            string: ThemeColor(light: "#0A3069", dark: "#0A3069"),
            number: ThemeColor(light: "#0550AE", dark: "#0550AE"),
            function: ThemeColor(light: "#8250DF", dark: "#8250DF"),
            variable: ThemeColor(light: "#953800", dark: "#953800"),
            type: ThemeColor(light: "#116329", dark: "#116329")
        )
    ]
}

struct ThemeColor: Codable, Hashable {
    var light: String
    var dark: String
    
    func color(for colorScheme: ColorScheme) -> Color {
        let hex = colorScheme == .dark ? dark : light
        return Color(hex: hex) ?? Color.primary
    }
    
    func nsColor(for colorScheme: ColorScheme) -> NSColor {
        let hex = colorScheme == .dark ? dark : light
        return NSColor(hex: hex) ?? NSColor.labelColor
    }
}

extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension NSColor {
    convenience init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(
            srgbRed: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}

