//
//  FindReplace.swift
//  FindReplace
//

import Foundation

public class FindReplaceManager {
    public init() {}
    
    public func findAndReplace(text: String, find: String, replace: String) -> String {
        return text.replacingOccurrences(of: find, with: replace)
    }
    
    public func find(text: String, searchTerm: String) -> [Int] {
        var indices: [Int] = []
        let lines = text.components(separatedBy: "\n")
        
        for (lineIndex, line) in lines.enumerated() {
            if line.contains(searchTerm) {
                indices.append(lineIndex)
            }
        }
        
        return indices
    }
}

public struct FindReplaceResult {
    public let line: Int
    public let position: Int
    public let match: String
    
    public init(line: Int, position: Int, match: String) {
        self.line = line
        self.position = position
        self.match = match
    }
}