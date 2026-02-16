# NewText — Native macOS Text Editor

A modern, native SwiftUI text editor for macOS 15+ inspired by Notepad++ and NotepadNext.

## ✅ Features

- **Multi-tab editing** with draggable tabs
- **Syntax highlighting** for Swift, Python, JavaScript, JSON, HTML, CSS
- **Dark & Light mode** with system appearance detection
- **Find & Replace** with regex and case-sensitive options
- **File browser sidebar** (Finder-like navigation)
- **Auto-completion** for keywords and bracket pairing
- **Code linting** with real-time underlines (indentation, unused variables)
- **Go to Definition** via ⌘+click
- **Project workspace support**
- **Customizable toolbar** with drag-and-drop buttons
- **Status bar** showing line/column, encoding, and file stats

## 🛠️ Build Instructions

### 1. Prerequisites
- macOS 15+
- Xcode 16+ (with Swift 6.2 toolchain)
- Basic familiarity with SwiftUI and macOS development

### 2. Setup
1. Clone or copy the entire `/Users/ewg/NewText` folder.
2. Open `NewText.xcodeproj` in Xcode (located at `/Users/ewg/NewText/Project/NewText.xcodeproj`).
3. Select **NewText** as the target.
4. Set Deployment Target to **macOS 15.0+**.

### 3. Build & Run
- Press **⌘ + R** to build and run.
- The app will launch with an empty untitled document.

### 4. Build for Distribution
1. Go to **Product → Archive**.
2. Once archived, click **Distribute App**.
3. Choose **Developer ID** or **Mac App Store**.
4. Follow the prompts to sign and export.

### 5. Dependencies
- No external dependencies — uses only native Swift/SwiftUI frameworks.

## 📁 File Structure

```
NewText/
├── AppDelegate.swift
├── ContentView.swift
├── Shared/
│   ├── Constants.swift
│   ├── Extensions.swift
│   └── Observables/
├── UI/
│   ├── Toolbar/
│   ├── Sidebar/
│   ├── Editor/
│   ├── Dialog/
│   ├── Modal/
│   └── StatusBar/
├── Services/
├── Models/
├── Assets/        # Xcode Asset Catalog (for icons)
└── Project/
    ├── Package.swift
    └── NewText.xcodeproj
```

## 📚 Technical Notes

- Uses **SwiftUI** exclusively — no AppKit interop.
- All state managed via `@StateObject` and `@ObservedObject`.
- Syntax highlighting uses **`AttributedString`** with regex patterns from `SyntaxMode`.
- File I/O handled via `FileManager`, async-safe.
- Undo/Redo leverages SwiftUI’s built-in `UndoManager`.

## 🚀 Future Enhancements

- Themes via `.xcassets` (color presets)
- Plugin system for custom syntaxes
- Git integration
- Terminal panel
- Multi-cursor editing

## 📜 License

MIT — Free to use, modify, and distribute.

