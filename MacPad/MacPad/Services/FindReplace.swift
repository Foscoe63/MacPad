import Foundation
import Combine

class FindReplaceService: ObservableObject {
    @Published var history: [String] = []
    @Published var lastSearchResult: SearchResult?
    
    init() {
        // Load saved history from UserDefaults
        if let saved = UserDefaults.standard.array(forKey: "FindHistory") as? [String] {
            history = saved
        }
    }
    
    func search(text: String, in content: String, caseSensitive: Bool = false, wholeWords: Bool = false, regex: Bool = false) -> [SearchResult] {
        var results: [SearchResult] = []
        
        guard !text.isEmpty else { return results }
        
        let options: String.CompareOptions = [
            caseSensitive ? [] : .caseInsensitive,
            wholeWords ? .anchored : []
        ] as String.CompareOptions
        
        if regex {
            do {
                let regex = try NSRegularExpression(pattern: text, options: [])
                let range = NSRange(location: 0, length: content.utf16.count)
                
                regex.enumerateMatches(in: content, options: [], range: range) { match, _, _ in
                    if let match = match {
                        let nsRange = match.range
                        guard let swiftRange = Range(nsRange, in: content) else { return }
                        
                        let line = content[..<swiftRange.lowerBound].components(separatedBy: .newlines).count
                        let column = content[swiftRange.lowerBound...].prefix(while: { $0 != "\n" }).count
                        
                        let result = SearchResult(
                            text: String(content[swiftRange]),
                            line: line + 1,
                            column: column + 1
                        )
                        
                        results.append(result)
                    }
                }
            } catch {
                print("Invalid regex pattern: \(error)")
            }
        } else {
            var startIndex = content.startIndex
            
            while let range = content.range(of: text, options: options, range: startIndex..<content.endIndex) {
                let line = content[..<range.lowerBound].components(separatedBy: .newlines).count
                let column = content[range.lowerBound...].prefix(while: { $0 != "\n" }).count
                
                let result = SearchResult(
                    text: String(content[range]),
                    line: line + 1,
                    column: column + 1
                )
                
                results.append(result)
                startIndex = range.upperBound
            }
        }
        
        return results
    }
    
    func replaceAll(_ findText: String, with replacement: String, in content: String, caseSensitive: Bool = false, wholeWords: Bool = false, regex: Bool = false) -> String {
        guard !findText.isEmpty else { return content }
        
        var result = content
        
        if regex {
            do {
                let regex = try NSRegularExpression(pattern: findText, options: [])
                result = regex.stringByReplacingMatches(in: content, options: [], range: NSRange(location: 0, length: content.utf16.count), withTemplate: replacement)
            } catch {
                print("Invalid regex pattern for replace: \(error)")
            }
        } else {
            let options: String.CompareOptions = [
                caseSensitive ? [] : .caseInsensitive,
                wholeWords ? .anchored : []
            ] as String.CompareOptions
            
            var startIndex = result.startIndex
            while let range = result.range(of: findText, options: options, range: startIndex..<result.endIndex) {
                result.replaceSubrange(range, with: replacement)
                startIndex = range.upperBound
            }
        }
        
        return result
    }
    
    func addSearchToHistory(_ term: String) {
        if !term.isEmpty && !history.contains(term) {
            history.insert(term, at: 0)
            
            // Keep only last 10 items
            if history.count > 10 {
                history.removeLast()
            }
            
            UserDefaults.standard.set(history, forKey: "FindHistory")
        }
    }
}