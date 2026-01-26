# MacPad — Native macOS Productivity Suite

A modern, native SwiftUI productivity suite for macOS 15+ featuring both a powerful text editor and KanBan board.

## ✅ Features

### Text Editor
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

### KanBan Board
- **Interactive task management** with drag-and-drop functionality
- **Four default columns**: To Do, In Progress, Review, Done
- **Task customization** with title, description, priority, due dates, and tags
- **Visual indicators** for task priority and status
- **Board statistics** with task breakdown by priority
- **Persistent storage** of tasks and boards
- **Easy switching** between text editor and KanBan board

## 🛠️ Build Instructions

### 1. Prerequisites
- macOS 15+
- Xcode 16+ (with Swift 6.2 toolchain)
- Basic familiarity with SwiftUI and macOS development

### 2. Setup
1. Clone or copy the entire `/Users/ewg/MacPad` folder.
2. Open `MacPad.xcodeproj` in Xcode (located at `/Users/ewg/MacPad/MacPad.xcodeproj`).
3. Select **MacPad** as the target.
4. Set Deployment Target to **macOS 15.0+**.

### 3. Build & Run
- Press **⌘ + R** to build and run.
- The app will launch with the ability to switch between text editor and KanBan board.

### 4. Build for Distribution
1. Go to **Product → Archive**.
2. Once archived, click **Distribute App**.
3. Choose **Developer ID** or **Mac App Store**.
4. Follow the prompts to sign and export.

### 5. Dependencies
- No external dependencies — uses only native Swift/SwiftUI frameworks.

## 📁 File Structure

```
MacPad/
├── AppDelegate.swift
├── ContentView.swift
├── Shared/
│   ├── Constants.swift
│   ├── Extensions.swift
│   └── Observables/
│       ├── AppState.swift
│       └── KanbanState.swift
├── UI/
│   ├── Toolbar/
│   ├── Sidebar/
│   ├── Editor/
│   ├── Dialog/
│   ├── Modal/
│   ├── StatusBar/
│   └── Kanban/
│       ├── KanbanBoardView.swift
│       ├── KanbanColumnView.swift
│       └── TaskCardView.swift
├── Services/
├── Models/
│   ├── Document.swift
│   ├── Task.swift
│   └── KanbanBoard.swift
├── Assets/        # Xcode Asset Catalog (for icons)
└── Project/
    ├── Package.swift
    └── MacPad.xcodeproj
```

## 📚 Technical Notes

- Uses **SwiftUI** exclusively — no AppKit interop.
- All state managed via `@StateObject` and `@ObservedObject`.
- Syntax highlighting uses **`AttributedString`** with regex patterns from `SyntaxMode`.
- File I/O handled via `FileManager`, async-safe.
- Undo/Redo leverages SwiftUI's built-in `UndoManager`.
- KanBan board persists data to user's Documents directory as JSON.

## 🚀 Future Enhancements

- Themes via `.xcassets` (color presets)
- Plugin system for custom syntaxes
- Git integration
- Terminal panel
- Multi-cursor editing
- Export KanBan boards to various formats
- Collaboration features for shared boards

## 📜 License

MIT — Free to use, modify, and distribute.