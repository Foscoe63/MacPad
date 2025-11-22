import SwiftUI

struct FindReplaceSheet: View {
    @Binding var isPresented: Bool
    @EnvironmentObject var document: Document
    @State private var findText = ""
    @State private var replaceText = ""
    @State private var useRegex = false
    @State private var matchCase = false
    @State private var wholeWords = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Find and Replace")
                .font(.title3)
                .fontWeight(.semibold)
            
            HStack {
                Text("Find:")
                    .frame(width: 80, alignment: .leading)
                TextField("Enter text to find", text: $findText)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Text("Replace:")
                    .frame(width: 80, alignment: .leading)
                TextField("Replacement text", text: $replaceText)
                    .textFieldStyle(.roundedBorder)
            }
            
            HStack {
                Toggle("Regex", isOn: $useRegex)
                    .toggleStyle(.switch)
                
                Toggle("Match Case", isOn: $matchCase)
                    .toggleStyle(.switch)
                
                Toggle("Whole Words", isOn: $wholeWords)
                    .toggleStyle(.switch)
            }
            
            Divider()
            
            Text("Preview")
                .font(.headline)
                .padding(.top, 8)
            
            ScrollView {
                Text(document.content)
                    .font(.system(size: Constants.fontSize, design: .monospaced))
                    .lineSpacing(2)
            }
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Replace") {
                    performReplacement()
                }
                .buttonStyle(.bordered)
                
                Button("Replace All") {
                    performAllReplacements()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(width: 500, height: 400)
    }
    
    private func performReplacement() {
        guard !findText.isEmpty else { return }
        
        let options: String.CompareOptions = [
            matchCase ? .caseInsensitive : [],
            wholeWords ? .anchored : []
        ] as String.CompareOptions
        
        var updatedContent = document.content
        let range = updatedContent.range(of: findText, options: options)
        
        if let range = range {
            updatedContent.replaceSubrange(range, with: replaceText)
            document.content = updatedContent
        }
    }
    
    private func performAllReplacements() {
        guard !findText.isEmpty else { return }
        
        let options: String.CompareOptions = [
            matchCase ? .caseInsensitive : [],
            wholeWords ? .anchored : []
        ] as String.CompareOptions
        
        var updatedContent = document.content
        let regex: NSRegularExpression?
        
        if useRegex {
            do {
                regex = try NSRegularExpression(pattern: findText, options: [])
            } catch {
                return
            }
            
            let range = NSRange(location: 0, length: updatedContent.utf16.count)
            let matches = regex?.matches(in: updatedContent, options: [], range: range) ?? []
            
            for match in matches.reversed() {
                let nsRange = match.range
                let swiftRange = Range(nsRange, in: updatedContent)
                
                if let swiftRange = swiftRange {
                    updatedContent.replaceSubrange(swiftRange, with: replaceText)
                }
            }
        } else {
            var startIndex = updatedContent.startIndex
            while let range = updatedContent.range(of: findText, options: options, range: startIndex..<updatedContent.endIndex) {
                updatedContent.replaceSubrange(range, with: replaceText)
                startIndex = range.upperBound
            }
        }
        
        document.content = updatedContent
    }
}