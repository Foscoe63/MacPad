# NewText â Native macOS Text Editor

A modern, native SwiftUI text editor for macOS 15+ inspired by Notepad++ and NotepadNext.

## â Features

- **Multi-tab editing** with draggable tabs
- **Syntax highlighting** for Swift, Python, JavaScript, JSON, HTML, CSS
- **Dark & Light mode** with system appearance detection
- **Find & Replace** with regex and case-sensitive options
- **File browser sidebar** (Finder-like navigation)
- **Auto-completion** for keywords and bracket pairing
- **Code linting** with real-time underlines (indentation, unused variables)
- **Go to Definition** via â+click
- **Project workspace support**
- **Customizable toolbar** with drag-and-drop buttons
- **Status bar** showing line/column, encoding, and file stats

## ð ï¸ Build Instructions

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
- Press **â + R** to build and run.
- The app will launch with an empty untitled document.

### 4. Build for Distribution
1. Go to **Product â Archive**.
2. Once archived, click **Distribute App**.
3. Choose **Developer ID** or **Mac App Store**.
4. Follow the prompts to sign and export.

### 5. Dependencies
- No external dependencies â uses only native Swift/SwiftUI frameworks.

## ð File Structure

```
NewText/
âââ AppDelegate.swift
âââ ContentView.swift
âââ Shared/
â   âââ Constants.swift
â   âââ Extensions.swift
â   âââ Observables/
âââ UI/
â   âââ Toolbar/
â   âââ Sidebar/
â   âââ Editor/
â   âââ Dialog/
â   âââ Modal/
â   âââ StatusBar/
âââ Services/
âââ Models/
âââ Assets/        # Xcode Asset Catalog (for icons)
âââ Project/
    âââ Package.swift
    âââ NewText.xcodeproj
```

## ð Technical Notes

- Uses **SwiftUI** exclusively â no AppKit interop.
- All state managed via `@StateObject` and `@ObservedObject`.
- Syntax highlighting uses **`AttributedString`** with regex patterns from `SyntaxMode`.
- File I/O handled via `FileManager`, async-safe.
- Undo/Redo leverages SwiftUIâs built-in `UndoManager`.

## ð Future Enhancements

- Themes via `.xcassets` (color presets)
- Plugin system for custom syntaxes
- Git integration
- Terminal panel
- Multi-cursor editing

## ð License

MIT â Free to use, modify, and distribute.

