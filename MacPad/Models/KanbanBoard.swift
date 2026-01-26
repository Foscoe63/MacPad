import Foundation

// MARK: - Kanban Board Model
class KanbanBoard: ObservableObject, Codable {
    @Published var columns: [KanbanColumn]
    @Published var title: String
    @Published var createdAt: Date
    @Published var updatedAt: Date
    
    init(
        title: String = "My Kanban Board",
        columns: [KanbanColumn] = TaskStatus.allCases.map { status in
            KanbanColumn(title: status.displayName, status: status, tasks: [])
        },
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.title = title
        self.columns = columns
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Codable Implementation
    enum CodingKeys: String, CodingKey {
        case title, createdAt, updatedAt, columns
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.title = try container.decode(String.self, forKey: .title)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        
        // Decode columns
        let decodedColumns = try container.decode([KanbanColumn].self, forKey: .columns)
        self.columns = decodedColumns
        
        // Initialize @Published property after decoding
        self._columns = Published(initialValue: decodedColumns)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encode(columns, forKey: .columns)
    }
    
    // MARK: - Methods
    func getTasks(for status: TaskStatus) -> [Task] {
        return columns.first { $0.status == status }?.tasks ?? []
    }
    
    func addTask(_ task: Task, to status: TaskStatus) {
        if let index = columns.firstIndex(where: { $0.status == status }) {
            columns[index].tasks.append(task)
            updatedAt = Date()
        }
    }
    
    func moveTask(_ task: Task, from oldStatus: TaskStatus, to newStatus: TaskStatus) {
        // Remove from old column
        if let oldColIndex = columns.firstIndex(where: { $0.status == oldStatus }),
           let taskIndex = columns[oldColIndex].tasks.firstIndex(where: { $0.id == task.id }) {
            let movedTask = columns[oldColIndex].tasks.remove(at: taskIndex)
            
            // Add to new column
            if let newColIndex = columns.firstIndex(where: { $0.status == newStatus }) {
                columns[newColIndex].tasks.append(movedTask)
                updatedAt = Date()
            }
        }
    }
    
    func updateTask(_ task: Task) {
        for i in 0..<columns.count {
            if let taskIndex = columns[i].tasks.firstIndex(where: { $0.id == task.id }) {
                columns[i].tasks[taskIndex] = task
                columns[i].tasks[taskIndex].updatedAt = Date()
                updatedAt = Date()
                break
            }
        }
    }
    
    func deleteTask(withId id: UUID) {
        for i in 0..<columns.count {
            if let taskIndex = columns[i].tasks.firstIndex(where: { $0.id == id }) {
                columns[i].tasks.remove(at: taskIndex)
                updatedAt = Date()
                break
            }
        }
    }
}

// MARK: - Kanban Column Model
struct KanbanColumn: Identifiable, Codable {
    let id: UUID
    var title: String
    var status: TaskStatus
    var tasks: [Task]
    
    init(
        id: UUID = UUID(),
        title: String,
        status: TaskStatus,
        tasks: [Task] = []
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.tasks = tasks
    }
    
    enum CodingKeys: String, CodingKey {
        case id, title, status, tasks
    }
}