import SwiftUI

struct KanbanColumnView: View {
    @StateObject var kanbanState = KanbanState.shared
    @State var column: KanbanColumn
    @State private var isAddingTask = false
    @State private var draggedTask: Task?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Column Header
            HStack {
                Text("\(column.title) (\(column.tasks.count))")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Add task button
                Button(action: {
                    isAddingTask = true
                }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Tasks in column
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(column.tasks) { task in
                        TaskCardView(task: task)
                            .onDrag {
                                draggedTask = task
                                return NSItemProvider(object: NSString(string: task.id.uuidString))
                            }
                            .onDrop(
                                of: [.plainText],
                                delegate: TaskDropDelegate(
                                    items: [task],
                                    destination: column.status,
                                    currentTask: task,
                                    draggedTask: $draggedTask,
                                    kanbanState: kanbanState
                                )
                            )
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .frame(minWidth: 280, maxWidth: 320)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .cornerRadius(12)
        .sheet(isPresented: $isAddingTask) {
            TaskCreationSheet(
                initialStatus: column.status,
                onSave: { newTask in
                    kanbanState.addTask(newTask)
                }
            )
        }
    }
}

struct TaskDropDelegate: DropDelegate {
    let items: [Task]
    let destination: TaskStatus
    let currentTask: Task
    let draggedTask: Binding<Task?>
    let kanbanState: KanbanState
    
    func performDrop(info: DropInfo) -> Bool {
        if let task = draggedTask.wrappedValue {
            // Move task to new column
            let oldStatus = task.status
            var updatedTask = task
            updatedTask.status = destination
            
            kanbanState.moveTask(updatedTask, from: oldStatus, to: destination)
            draggedTask.wrappedValue = nil
        }
        return true
    }
    
    func dropEntered(info: DropInfo) {
        // Handle visual feedback when item enters drop zone
    }
    
    func dropUpdated(info: DropInfo) -> DropProposal? {
        return DropProposal(operation: .move)
    }
    
    func dropExited(info: DropInfo) {
        // Handle visual feedback when item exits drop zone
    }
}

struct TaskCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var initialStatus: TaskStatus
    let onSave: (Task) -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var status: TaskStatus = .todo
    @State private var priority = TaskPriority.medium
    @State private var assignee = ""
    @State private var dueDate: Date?
    @State private var tagsText = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("Task Details") {
                    TextField("Title", text: $title)
                    
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(5...10)
                    
                    Picker("Status", selection: $status) {
                        ForEach(TaskStatus.allCases, id: \.self) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    Picker("Priority", selection: $priority) {
                        ForEach(TaskPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }
                
                Section("Additional Info") {
                    DatePicker("Due Date", selection: Binding(
                        get: { dueDate ?? Date() },
                        set: { dueDate = $0 }
                    ), displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(GraphicalDatePickerStyle())
                    
                    TextField("Assignee", text: $assignee)
                    
                    TextField("Tags (comma separated)", text: $tagsText)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let tags = tagsText.split(separator: ",").map { tag in
                            tag.trimmingCharacters(in: .whitespaces)
                        }.filter { !$0.isEmpty }
                        
                        let newTask = Task(
                            title: title,
                            description: description,
                            status: status,
                            priority: priority,
                            assignee: assignee.isEmpty ? nil : assignee,
                            dueDate: dueDate,
                            tags: tags
                        )
                        
                        onSave(newTask)
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onAppear {
                status = initialStatus
            }
        }
    }
}

#Preview {
    KanbanColumnView(
        column: KanbanColumn(
            title: "To Do",
            status: .todo,
            tasks: [
                Task(
                    title: "Sample Task 1",
                    description: "This is a sample task description.",
                    status: .todo,
                    priority: .high
                ),
                Task(
                    title: "Sample Task 2",
                    description: "Another sample task.",
                    status: .todo,
                    priority: .medium
                )
            ]
        )
    )
}