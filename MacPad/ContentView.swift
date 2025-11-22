import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var appState = AppState.shared
    @StateObject private var workspaceState = WorkspaceState()
    @AppStorage("app.theme") private var appTheme: String = "light" // system, light, dark
    @Environment(\.scenePhase) private var scenePhase

    // Sidebar resizing state
    @State private var sidebarWidth: CGFloat = 260
    @State private var sidebarWidthBaseline: CGFloat = 260
    @State private var isHoveringDivider: Bool = false
    private let minSidebarWidth: CGFloat = 180
    private let maxSidebarWidth: CGFloat = 600
    
    // Quick Open state
    @State private var showingQuickOpen = false
    @State private var showingGoToLine = false

    private var preferredScheme: ColorScheme? {
        switch appTheme.lowercased() {
        case "light": return .light
        case "dark": return .dark
        case "sepia": return .light
        case "highcontrast": return .dark
        default: return nil
        }
    }
    
    // Themed palette for custom appearances
    private var isSepia: Bool { appTheme.lowercased() == "sepia" }
    private var isHighContrast: Bool { appTheme.lowercased() == "highcontrast" }
    private var sidebarBgColor: Color {
        if isSepia { return Color(nsColor: NSColor(calibratedRed: 0.975, green: 0.958, blue: 0.914, alpha: 1.0)) }
        if isHighContrast { return Color(nsColor: NSColor(calibratedWhite: 0.10, alpha: 1.0)) }
        return Color(nsColor: .windowBackgroundColor)
    }
    private var headerBgColor: Color {
        if isSepia { return Color(nsColor: NSColor(calibratedRed: 0.965, green: 0.945, blue: 0.900, alpha: 1.0)) }
        if isHighContrast { return Color(nsColor: NSColor(calibratedWhite: 0.14, alpha: 1.0)) }
        return Color.clear // fall back to default toolbar material
    }
    private var mainBgColor: Color {
        if isSepia { return Color(nsColor: NSColor(calibratedRed: 0.988, green: 0.972, blue: 0.938, alpha: 1.0)) }
        if isHighContrast { return Color(nsColor: NSColor(calibratedWhite: 0.06, alpha: 1.0)) }
        return Color.clear
    }
    private var splitHoverColor: Color {
        if isSepia { return Color.brown.opacity(0.20) }
        if isHighContrast { return Color.white.opacity(0.35) }
        return Color.accentColor.opacity(0.15)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                // File Browser header bar
                HStack {
                    Spacer()
                    Text("File Browser")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Spacer()
                }
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .background(.bar)
                .overlay((isSepia || isHighContrast) ? headerBgColor : Color.clear)
                
                Divider()
                
                // File tree content
                ScrollView {
                    FileBrowserView()
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(width: sidebarWidth, alignment: .topLeading)
            .frame(maxHeight: .infinity)
            .background(sidebarBgColor)

            // Draggable divider/handle
            SplitHandle(isHovering: $isHoveringDivider, hoverColor: splitHoverColor)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let proposed = sidebarWidthBaseline + value.translation.width
                            sidebarWidth = clampWidth(proposed)
                        }
                        .onEnded { _ in
                            sidebarWidthBaseline = sidebarWidth
                        }
                )
                .onHover { hovering in
                    isHoveringDivider = hovering
                    if hovering {
                        NSCursor.resizeLeftRight.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                }

            // Main Editor Area
            VStack(spacing: 0) {
                ToolbarView()
                    .frame(height: Constants.toolbarHeight)

                TabStripView()

                Group {
                    if let doc = appState.getDocument(id: appState.selectedTab) {
                        EditorView(document: doc)
                    } else if let first = appState.documents.first {
                        EditorView(document: first)
                    } else {
                        Text("No document")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let doc = appState.getDocument(id: appState.selectedTab) {
                    StatusBarView(document: doc)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .environmentObject(workspaceState)
        .environmentObject(appState)
        .frame(minWidth: 800, minHeight: 500)
        .preferredColorScheme(preferredScheme)
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .inactive, .background:
                appState.saveSessionIfEnabled()
            default:
                break
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            appState.saveSessionIfEnabled()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willResignActiveNotification)) { _ in
            appState.saveSessionIfEnabled()
        }
        .sheet(isPresented: $showingQuickOpen) {
            QuickOpenView(isPresented: $showingQuickOpen)
                .environmentObject(workspaceState)
                .environmentObject(appState)
        }
        .sheet(isPresented: $showingGoToLine) {
            if let doc = appState.getDocument(id: appState.selectedTab) {
                GoToLineView(isPresented: $showingGoToLine, document: doc)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .mpQuickOpen)) { _ in
            showingQuickOpen = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .mpGoToLine)) { _ in
            showingGoToLine = true
        }
    }
    
    private func clampWidth(_ w: CGFloat) -> CGFloat {
        min(max(w, minSidebarWidth), maxSidebarWidth)
    }
}

private struct SplitHandle: View {
    @Binding var isHovering: Bool
    let hoverColor: Color

    var body: some View {
        ZStack {
            // Visual divider line
            Divider()
            // Wider invisible hit area for easier dragging
            Rectangle()
                .fill(Color.clear)
                .frame(width: 6)
                .contentShape(Rectangle())
        }
        .frame(width: 6)
        .frame(maxHeight: .infinity)
        .background(isHovering ? hoverColor : Color.clear)
    }
}