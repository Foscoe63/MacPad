import SwiftUI

struct PreferenceSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    @StateObject private var appState = AppState()
    
    @State private var selectedTheme: String = "System"
    @State private var fontSize: CGFloat = 14.0
    @State private var showLineNumbers = true
    
    let themes = ["System", "Dark", "Light"]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Preferences")
                .font(.title3)
                .fontWeight(.semibold)
            
            Divider()
            
            Section("Appearance") {
                Picker("Theme", selection: $selectedTheme) {
                    Text("System").tag("System")
                    Text("Dark").tag("Dark")
                    Text("Light").tag("Light")
                }
                .pickerStyle(.segmented)
                
                HStack {
                    Text("Font Size")
                        .frame(width: 100, alignment: .leading)
                    Slider(value: $fontSize, in: 10...24, step: 1)
                        .padding(.leading, 8)
                    Text("\(Int(fontSize))")
                        .frame(width: 40)
                }
                
                Toggle("Show Line Numbers", isOn: $showLineNumbers)
            }
            
            Divider()
            
            Section("Editor") {
                Toggle("Auto-indent", isOn: .constant(true))
                Toggle("Auto-close Brackets", isOn: .constant(true))
                Toggle("Word Wrap", isOn: .constant(false))
            }
            
            Divider()
            
            Section("Shortcuts") {
                Text("Command + S: Save")
                    .font(.caption)
                
                Text("Command + F: Find")
                    .font(.caption)
                
                Text("Command + R: Replace")
                    .font(.caption)
            }
            
            Spacer()
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Apply") {
                    // Apply settings
                    isPresented = false
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 400, height: 500)
    }
}