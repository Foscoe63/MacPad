import SwiftUI

struct PreferencesRootView: View {
    @AppStorage("prefs.selectedPane") private var selectedPane: PreferencesPane = .application
    @AppStorage("app.theme") private var theme: String = "light" // keep in sync with ContentView default
    
    private var preferredScheme: ColorScheme? {
        switch theme.lowercased() {
        case "light": return .light
        case "dark": return .dark
        case "sepia": return .light
        case "highcontrast": return .dark
        // Additional macOS themes – map to a base scheme so the UI updates.
        case "graphite": return .dark
        case "vibrant-light": return .light
        case "vibrant-dark": return .dark
        default: return nil // custom themes are handled by ThemeManager without forcing a scheme
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            List(selection: $selectedPane) {
                Section(footer: EmptyView()) {
                    NavigationRow(pane: .application)
                    NavigationRow(pane: .editor)
                    NavigationRow(pane: .advanced)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 200)
            .background(.quaternary.opacity(0.1))
            
            Divider()
                .frame(maxHeight: .infinity)
            
            // Detail
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch selectedPane {
                    case .application:
                        ApplicationPreferencesView()
                    case .editor:
                        EditorPreferencesView()
                    case .advanced:
                        AdvancedPreferencesView()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .frame(minWidth: 420, maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 680, minHeight: 420)
        .preferredColorScheme(preferredScheme)
    }
}

private struct NavigationRow: View {
    let pane: PreferencesPane
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: pane.icon)
                .font(.system(size: 16))
                .frame(width: 22)
            Text(pane.title)
                .font(.system(size: 13, weight: .medium))
            Spacer()
        }
        .tag(pane)
        .padding(.vertical, 6)
    }
}

enum PreferencesPane: String, CaseIterable, Identifiable, Codable {
    case application, editor, advanced
    var id: String { rawValue }
    var title: String {
        switch self {
        case .application: return "Application"
        case .editor: return "Editor"
        case .advanced: return "Advanced"
        }
    }
    var icon: String {
        switch self {
        case .application: return "gearshape"
        case .editor: return "pencil.and.outline"
        case .advanced: return "wrench.and.screwdriver"
        }
    }
}

// MARK: - Panes

private struct ApplicationPreferencesView: View {
    @AppStorage("app.theme") private var theme: String = "system" // system, light, dark
    @AppStorage("app.restoreWorkspace") private var restoreLastWorkspace: Bool = true
    @AppStorage("application.textMode") private var textMode: String = "plain" // plain, rich
            // File Browser font prefs
    @AppStorage("browser.fontDesign") private var browserFontDesign: String = "system" // system | monospaced
    @AppStorage("browser.fontSize") private var browserFontSize: Double = 13
    @AppStorage("browser.sortOrder") private var sortOrder: String = "name" // comma-separated: name,type,date,size
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Application")
                .font(.title3).bold()
            
            // Theme
            VStack(alignment: .leading) {
                Text("Appearance").font(.headline)
                Picker("Theme", selection: $theme) {
                    Text("System").tag("system")
                    Text("Light").tag("light")
                    Text("Dark").tag("dark")
                    Text("Sepia").tag("sepia")
                    Text("High Contrast").tag("highcontrast")
                }
                .pickerStyle(.segmented)

                // Additional macOS themes not covered by the segmented picker.
                // Each button directly sets the stored theme string.
                VStack(alignment: .leading, spacing: 6) {
                    Text("Additional Themes").font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Button("Graphite") { theme = "graphite" }
                        Button("Vibrant Light") { theme = "vibrant-light" }
                        Button("Vibrant Dark") { theme = "vibrant-dark" }
                    }
                }
                .padding(.top, 4)
            }

            Divider().padding(.vertical, 6)
            VStack(alignment: .leading, spacing: 8) {
                Text("Editor Text Mode").font(.headline)
                Picker("Text Mode", selection: $textMode) {
                    Text("Plain Text").tag("plain")
                    Text("Rich Text").tag("rich")
                }
                .pickerStyle(.segmented)
                Text("Rich Text enables bold/italic/underline and other text attributes. Currently, only the plain text content is persisted across app restarts.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Text("Changes apply immediately").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: 320)

            Toggle("Restore last workspace on launch", isOn: $restoreLastWorkspace)

            Divider().padding(.vertical, 6)
            // File Browser Font controls
            VStack(alignment: .leading, spacing: 10) {
                Text("File Browser Font").font(.headline)
                HStack(spacing: 12) {
                    Text("Style").frame(width: 120, alignment: .leading)
                    Picker("Style", selection: $browserFontDesign) {
                        Text("System").tag("system")
                        Text("Monospaced").tag("monospaced")
                    }
                    .pickerStyle(.segmented)
                }
                HStack(spacing: 12) {
                    Text("Size").frame(width: 120, alignment: .leading)
                    Slider(value: $browserFontSize, in: 10...20, step: 1)
                        .frame(maxWidth: 240)
                    Text("\(Int(browserFontSize)) pt").frame(width: 60, alignment: .trailing)
                }
                // Live preview
                let previewFont: Font = {
                    let size = CGFloat(browserFontSize)
                    if browserFontDesign == "monospaced" {
                        return .system(size: size, design: .monospaced)
                    } else {
                        return .system(size: size)
                    }
                }()
                Text("Preview · Folder Name · File.swift · External Drive")
                    .font(previewFont)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .padding(.leading, 120)
            }
            
            Divider().padding(.vertical, 6)
            // File Browser Sort Order (multi-level)
            VStack(alignment: .leading, spacing: 10) {
                Text("File Browser Sort Order").font(.headline)
                Text("Select multiple criteria to sort by. Items are sorted by the first criterion, then by the second, and so on.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                
                SortOrderSelector(selectedOrders: $sortOrder)
            }
        }
    }
}

private struct EditorPreferencesView: View {
    @AppStorage("editor.fontSize") private var fontSize: Double = 14
    @AppStorage("editor.lineSpacing") private var lineSpacing: Double = 2.0
    @AppStorage("editor.showLineNumbers") private var showLineNumbers: Bool = true
    @AppStorage("editor.softTabs") private var useSoftTabs: Bool = true
    @AppStorage("editor.tabWidth") private var tabWidth: Int = 4
    @AppStorage("editor.autoSaveEnabled") private var autoSave: Bool = false
    @AppStorage("editor.autoSaveInterval") private var autoSaveInterval: Int = 30
    @AppStorage("editor.restoreUnsavedOnLaunch") private var restoreUnsavedOnLaunch: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Editor").font(.title3).bold()
            
            HStack {
                Text("Font Size").frame(width: 120, alignment: .leading)
                Slider(value: $fontSize, in: 10...24, step: 1)
                    .frame(maxWidth: 240)
                Text("\(Int(fontSize)) pt").frame(width: 60, alignment: .trailing)
            }
            
            HStack {
                Text("Line Spacing").frame(width: 120, alignment: .leading)
                Slider(value: $lineSpacing, in: 1.0...3.0, step: 0.1)
                    .frame(maxWidth: 240)
                Text(String(format: "%.1f", lineSpacing)).frame(width: 60, alignment: .trailing)
            }
            
            Toggle("Show line numbers", isOn: $showLineNumbers)
            
            Toggle("Word wrap", isOn: Binding(
                get: { UserDefaults.standard.bool(forKey: "editor.wordWrap") },
                set: { UserDefaults.standard.set($0, forKey: "editor.wordWrap") }
            ))
            
            Toggle("Use spaces instead of tabs", isOn: $useSoftTabs)
            HStack {
                Text("Tab Width").frame(width: 120, alignment: .leading)
                Stepper(value: $tabWidth, in: 2...8, step: 1) {
                    Text("\(tabWidth) spaces")
                }
                .frame(maxWidth: 240, alignment: .leading)
            }
            
            Toggle("Auto-save", isOn: $autoSave)
            HStack {
                Text("Auto-save Interval").frame(width: 120, alignment: .leading)
                Stepper(value: $autoSaveInterval, in: 5...300, step: 5) {
                    Text("\(autoSaveInterval) s")
                }
                .frame(maxWidth: 240, alignment: .leading)
            }
            
            Divider().padding(.vertical, 4)
            Toggle("Restore unsaved documents on launch", isOn: $restoreUnsavedOnLaunch)
                .onChange(of: restoreUnsavedOnLaunch) { _, newValue in
                    if newValue == false {
                        let defaults = UserDefaults.standard
                        defaults.removeObject(forKey: "session.openDocuments.v1")
                        defaults.removeObject(forKey: "session.selectedIndex.v1")
                        _ = defaults.synchronize()
                    }
                }
        }
    }
}

private struct AdvancedPreferencesView: View {
    // Existing advanced prefs
    @AppStorage("advanced.autocomplete") private var autoComplete: Bool = true
    @AppStorage("advanced.linting") private var linting: Bool = true
    @AppStorage("advanced.highlightIntensity") private var highlightIntensity: Double = 1.0
    // New: File Browser / Volumes visibility
    @AppStorage("browser.showHidden") private var showHiddenFiles: Bool = false
    @AppStorage("volumes.showInternal") private var showInternal: Bool = true
    @AppStorage("volumes.showExternal") private var showExternal: Bool = true
    @AppStorage("volumes.showNetwork") private var showNetwork: Bool = false
    @AppStorage("volumes.hideSystem") private var hideSystem: Bool = true
    @AppStorage("volumes.hideBackups") private var hideBackups: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced").font(.title3).bold()
            
            GroupBox("Devices shown in File Browser") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Show internal drives", isOn: $showInternal)
                    Toggle("Show external/removable drives", isOn: $showExternal)
                    Toggle("Show network volumes", isOn: $showNetwork)
                    Divider().padding(.vertical, 4)
                    Toggle("Hide system volumes (Preboot, VM, Update, RAID, iSCPreboot, Hardware, Recovery, xART)", isOn: $hideSystem)
                    Toggle("Hide backup volumes and snapshots (Time Machine, MobileBackups)", isOn: $hideBackups)
                    Divider().padding(.vertical, 4)
                    Toggle("Show hidden files in File Browser", isOn: $showHiddenFiles)
                        .help("Toggles dotfiles like .git, .env, etc.")
                }
                .padding(8)
            }
            
            GroupBox("Editing") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enable Autocomplete", isOn: $autoComplete)
                    Toggle("Enable Linting", isOn: $linting)
                    Toggle("Enable Go to Definition (⌘+click)", isOn: Binding(
                        get: { UserDefaults.standard.bool(forKey: "editor.goToDefinition") },
                        set: { UserDefaults.standard.set($0, forKey: "editor.goToDefinition") }
                    ))
                    HStack {
                        Text("Highlight Intensity").frame(width: 160, alignment: .leading)
                        Slider(value: $highlightIntensity, in: 0.3...1.5, step: 0.1)
                            .frame(maxWidth: 240)
                        Text(String(format: "%.1f×", highlightIntensity))
                    }
                }
                .padding(8)
            }
            
            GroupBox("Tabs") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Enable draggable tabs", isOn: Binding(
                        get: { UserDefaults.standard.bool(forKey: "tabs.draggable") },
                        set: { UserDefaults.standard.set($0, forKey: "tabs.draggable") }
                    ))
                    Text("Allow dragging tabs to reorder them")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }
        }
    }
}

// MARK: - Sort Order Selector

private struct SortOrderSelector: View {
    @Binding var selectedOrders: String
    
    private let availableOrders: [(key: String, label: String)] = [
        ("name", "Name"),
        ("type", "Type"),
        ("date", "Date Modified"),
        ("size", "Size")
    ]
    
    private var selectedKeys: [String] {
        selectedOrders.split(separator: ",").map { String($0.trimmingCharacters(in: .whitespaces)) }.filter { !$0.isEmpty }
    }
    
    private func isSelected(_ key: String) -> Bool {
        selectedKeys.contains(key)
    }
    
    private func toggleOrder(_ key: String) {
        var current = selectedKeys
        if let index = current.firstIndex(of: key) {
            current.remove(at: index)
        } else {
            current.append(key)
        }
        selectedOrders = current.isEmpty ? "name" : current.joined(separator: ",")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Selected sort orders (in order)
            if !selectedKeys.isEmpty {
                Text("Sort by (in order):")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                ForEach(Array(selectedKeys.enumerated()), id: \.offset) { index, key in
                    if let order = availableOrders.first(where: { $0.key == key }) {
                        HStack {
                            Text("\(index + 1).")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Text(order.label)
                                .font(.system(size: 13))
                            Spacer()
                            Button(action: { toggleOrder(key) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                    }
                }
            }
            
            Divider().padding(.vertical, 4)
            
            // Available sort orders (to add)
            Text("Add sort criteria:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                ForEach(availableOrders, id: \.key) { order in
                    Button(action: { toggleOrder(order.key) }) {
                        HStack(spacing: 4) {
                            if isSelected(order.key) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                            Text(order.label)
                                .font(.system(size: 12))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(isSelected(order.key) ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor).opacity(0.5))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if selectedKeys.isEmpty {
                Text("No sort criteria selected. Files will be sorted by name by default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
    }
}
