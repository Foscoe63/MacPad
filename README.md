# MacPad - Dual-Mode Text Editor and KanBan Board

MacPad is a sophisticated macOS productivity application that combines a feature-rich text editor with an interactive KanBan board in a single, seamless interface.

## Features

### Text Editor
- Full-featured text editor with syntax highlighting for multiple programming languages
- File browser sidebar for easy navigation
- Tabbed document interface
- Find and replace functionality
- Auto-save and session restoration
- Support for multiple file formats
- Customizable themes and appearance options

### KanBan Board
- Interactive four-column KanBan board (To Do, In Progress, Review, Done)
- Drag-and-drop task management between columns
- Rich task details including title, description, priority, due dates, assignees, and tags
- Statistics dashboard with progress tracking
- Persistent storage of tasks and board state
- Visual indicators for task status and priority

## Architecture

The application is built using:
- SwiftUI for the native macOS user interface
- Swift Package Manager for modular code organization
- Core Data or file-based persistence for storing documents and tasks
- Modern Swift concurrency patterns

### Package Structure
- `FindReplace`: Provides find and replace functionality
- `SyntaxHighlighting`: Implements syntax highlighting for various programming languages
- `Autocomplete`: Offers intelligent code completion
- `CodeLinter`: Provides code quality analysis and linting

## Installation

To build and run MacPad:

1. Clone the repository:
   ```bash
   git clone <repository-url>
   cd MacPad
   ```

2. Build the project:
   ```bash
   swift build
   ```

3. To run tests:
   ```bash
   swift test
   ```

## Usage

When you launch MacPad, you'll see a tabbed interface with two main sections:

1. **Editor Tab**: Access the full-featured text editor
2. **Kanban Tab**: Switch to the KanBan board for project management

The application remembers your last session, including open files and the state of your KanBan board.

## Development

The project follows modern Swift development practices:
- Clean, modular architecture using Swift Packages
- Comprehensive documentation
- Proper error handling
- Adherence to Swift API Guidelines

## License

This project is available under the MIT license.