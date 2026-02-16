import Foundation

struct SearchResult: Identifiable {
    let id = UUID()
    let text: String
    let line: Int
    let column: Int
    let filePath: String?
    
    init(text: String, line: Int, column: Int, filePath: String? = nil) {
        self.text = text
        self.line = line
        self.column = column
        self.filePath = filePath
    }
}