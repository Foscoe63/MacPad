import Foundation
import SwiftUI

// MARK: - Task Model
struct Task: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var status: TaskStatus
    var priority: TaskPriority
    var createdAt: Date
    var updatedAt: Date
    var assignee: String?
    var dueDate: Date?
    var tags: [String]
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        status: TaskStatus = .todo,
        priority: TaskPriority = .medium,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        assignee: String? = nil,
        dueDate: Date? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.status = status
        self.priority = priority
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.assignee = assignee
        self.dueDate = dueDate
        self.tags = tags
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, status, priority, createdAt, updatedAt, assignee, dueDate, tags
    }
}

// MARK: - Task Status Enum
enum TaskStatus: String, CaseIterable, Codable, Equatable {
    case todo = "To Do"
    case inProgress = "In Progress"
    case review = "Review"
    case done = "Done"
    
    var displayName: String { self.rawValue }
    var color: Color {
        switch self {
        case .todo: return .gray
        case .inProgress: return .orange
        case .review: return .blue
        case .done: return .green
        }
    }
}

// MARK: - Task Priority Enum
enum TaskPriority: String, CaseIterable, Codable, Equatable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
    
    var displayName: String { self.rawValue }
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}