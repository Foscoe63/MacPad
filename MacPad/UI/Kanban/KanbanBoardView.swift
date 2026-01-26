import SwiftUI

struct KanbanBoardView: View {
    @StateObject var kanbanState = KanbanState.shared
    @State private var showingBoardSettings = false
    @State private var showingStats = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Toolbar for Kanban Board
            HStack {
                Text(kanbanState.currentBoard.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    showingStats = true
                }) {
                    Image(systemName: "chart.bar")
                        .foregroundColor(.secondary)
                }
                .help("View Board Statistics")
                
                Button(action: {
                    showingBoardSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                }
                .help("Board Settings")
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.headerColor))
            .border(Color(NSColor.separatorColor))
            
            // Kanban Columns
            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 16) {
                    ForEach(kanbanState.currentBoard.columns) { column in
                        KanbanColumnView(column: column)
                    }
                }
                .padding(.all, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .sheet(isPresented: $showingBoardSettings) {
            BoardSettingsView()
        }
        .sheet(isPresented: $showingStats) {
            BoardStatisticsView()
        }
        .onDrop(of: [.plainText], delegate: BoardDropDelegate(kanbanState: kanbanState))
    }
}

struct BoardDropDelegate: DropDelegate {
    let kanbanState: KanbanState
    
    func performDrop(info: DropInfo) -> Bool {
        // Handle drops at the board level
        return true
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
}

struct BoardSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var kanbanState = KanbanState.shared
    
    @State private var boardTitle = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Board Settings") {
                    TextField("Board Title", text: $boardTitle)
                }
                
                Section("Board Actions") {
                    Button("Reset Board") {
                        // Confirm before resetting
                        let alert = NSAlert()
                        alert.messageText = "Reset Board"
                        alert.informativeText = "Are you sure you want to reset the board? All tasks will be cleared."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "Reset")
                        alert.addButton(withTitle: "Cancel")
                        
                        if alert.runModal() == .alertFirstButtonReturn {
                            // Create a new empty board
                            kanbanState.createNewBoard(title: boardTitle.isEmpty ? "My Kanban Board" : boardTitle)
                        }
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Board Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var updatedBoard = kanbanState.currentBoard
                        updatedBoard.title = boardTitle.isEmpty ? "My Kanban Board" : boardTitle
                        kanbanState.loadBoard(updatedBoard)
                        dismiss()
                    }
                }
            }
            .onAppear {
                boardTitle = kanbanState.currentBoard.title
            }
        }
    }
}

struct BoardStatisticsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject var kanbanState = KanbanState.shared
    
    var body: some View {
        NavigationView {
            VStack {
                // Summary Cards
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 2), spacing: 16) {
                    StatCard(title: "Total Tasks", value: "\(kanbanState.currentBoard.columns.reduce(0) { $0 + $1.tasks.count })", color: .blue)
                    
                    StatCard(title: "To Do", value: "\(kanbanState.currentBoard.getTasks(for: .todo).count)", color: .gray)
                    
                    StatCard(title: "In Progress", value: "\(kanbanState.currentBoard.getTasks(for: .inProgress).count)", color: .orange)
                    
                    StatCard(title: "Completed", value: "\(kanbanState.currentBoard.getTasks(for: .done).count)", color: .green)
                }
                .padding()
                
                // Task Breakdown
                VStack(alignment: .leading, spacing: 12) {
                    Text("Task Breakdown")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    ForEach(TaskPriority.allCases, id: \.self) { priority in
                        HStack {
                            Text(priority.displayName)
                                .frame(width: 80, alignment: .leading)
                            
                            ProgressBar(
                                value: calculatePriorityPercentage(priority),
                                color: priority.color
                            )
                            
                            Text("\(calculatePriorityCount(priority))")
                                .frame(width: 30, alignment: .trailing)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                
                Spacer()
            }
            .navigationTitle("Board Statistics")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func calculatePriorityCount(_ priority: TaskPriority) -> Int {
        return kanbanState.currentBoard.columns.flatMap { $0.tasks }.filter { $0.priority == priority }.count
    }
    
    private func calculatePriorityPercentage(_ priority: TaskPriority) -> Double {
        let totalCount = kanbanState.currentBoard.columns.flatMap { $0.tasks }.count
        guard totalCount > 0 else { return 0 }
        return Double(calculatePriorityCount(priority)) / Double(totalCount)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(value)
                .font(.largeTitle)
                .fontWeight(.semibold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct ProgressBar: View {
    let value: Double
    let color: Color
    let height: CGFloat = 8
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: height)
                
                // Filled portion
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(color)
                    .frame(width: max(0, geometry.size.width * value), height: height)
            }
        }
        .frame(height: height)
    }
}

#Preview {
    KanbanBoardView()
        .frame(width: 1200, height: 600)
}