import SwiftUI

struct ToolbarCustomizerView: View {
    @State private var showSheet = false
    
    var body: some View {
        Button("Customize Toolbar") {
            showSheet = true
        }
        .sheet(isPresented: $showSheet) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Toolbar Items")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                List {
                    ForEach(["New", "Open", "Save", "Find", "Theme"], id: \.self) { item in
                        HStack {
                            Text(item)
                            Spacer()
                            Toggle("", isOn: .constant(true))
                                .toggleStyle(.switch)
                        }
                    }
                }
                
                Button("Done") {
                    showSheet = false
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}