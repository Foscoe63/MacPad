import Foundation
import SwiftUI

// MARK: - Kanban State Manager
class KanbanState: ObservableObject {
    static let shared = KanbanState()
    
    @Published var currentBoard: KanbanBoard
    @Published var isLoading: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    
    private init() {
        // Load saved board or create default
        if let savedBoard = loadSavedBoard() {
            self.currentBoard = savedBoard
        } else {
            self.currentBoard = KanbanBoard()
        }
    }
    
    // MARK: - Persistence
    private func documentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func boardFileURL() -> URL {
        documentsDirectory().appendingPathComponent("kanban-board.json")
    }
    
    func saveBoard() {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let data = try JSONEncoder().encode(currentBoard)
            try data.write(to: boardFileURL(), options: [.atomic, .completeFileProtection])
        } catch {
            print("Error saving board: \(error)")
            showError = true
            errorMessage = "Failed to save board: \(error.localizedDescription)"
        }
    }
    
    func loadSavedBoard() -> KanbanBoard? {
        let fileURL = boardFileURL()
        
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let board = try JSONDecoder().decode(KanbanBoard.self, from: data)
            return board
        } catch {
            print("Error loading board: \(error)")
            return nil
        }
    }
    
    // MARK: - Task Management
    func addTask(_ task: Task) {
        currentBoard.addTask(task, to: task.status)
        saveBoard()
    }
    
    func updateTask(_ task: Task) {
        currentBoard.updateTask(task)
        saveBoard()
    }
    
    func deleteTask(withId id: UUID) {
        currentBoard.deleteTask(withId: id)
        saveBoard()
    }
    
    func moveTask(_ task: Task, from oldStatus: TaskStatus, to newStatus: TaskStatus) {
        currentBoard.moveTask(task, from: oldStatus, to: newStatus)
        saveBoard()
    }
    
    // MARK: - Board Management
    func createNewBoard(title: String) {
        currentBoard = KanbanBoard(title: title)
        saveBoard()
    }
    
    func loadBoard(_ board: KanbanBoard) {
        currentBoard = board
        saveBoard()
    }
}