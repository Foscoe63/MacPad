import SwiftUI

struct TaskCardView: View {
    @StateObject var kanbanState = KanbanState.shared
    @State var task: Task
    @State private var isEditing = false
    @State private var editedTask: Task
    
    init(task: Task) {
        self.task = task
        self._editedTask = State(initialValue: task)
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 8) {
                // Task title
                Text(editedTask.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                // Task description
                if !editedTask.description.isEmpty {
                    Text(editedTask.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(3)
                }
                
                // Due date and assignee
                if let dueDate = editedTask.dueDate {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text(formatDate(dueDate))
                            .font(.caption)
                            .foregroundColor(isOverdue(dueDate) ? .red : .secondary)
                    }
                }
                
                if let assignee = editedTask.assignee {
                    HStack {
                        Image(systemName: "person")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text(assignee)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Tags
                if !editedTask.tags.isEmpty {
                    HStack {
                        ForEach(editedTask.tags, id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption2)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                
                Spacer()
                
                // Priority indicator
                HStack {
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(editedTask.priority.color)
                            .frame(width: 8, height: 8)
                        
                        Text(editedTask.priority.displayName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
            
            // Edit button
            Button(action: {
                isEditing = true
            }) {
                Image(systemName: "pencil.circle.fill")
                    .foregroundColor(.blue)
                    .font(.title2)
                    .padding(4)
                    .background(Color.white)
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            .zIndex(1)
        }
        .onTapGesture {
            isEditing = true
        }
        .sheet(isPresented: $isEditing) {
            TaskEditSheet(task: $editedTask, onSave: {
                kanbanState.updateTask(editedTask)
            })
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func isOverdue(_ date: Date) -> Bool {
        return date < Date()
    }
}

struct TaskEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var task: Task
    let onSave: () -> Void
    
    @State private var title = ""
    @State private var description = ""
    @State private var status = TaskStatus.todo
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
                        .onAppear {
                            tagsText = task.tags.joined(separator: ", ")
                        }
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        // Update the task
                        task.title = title
                        task.description = description
                        task.status = status
                        task.priority = priority
                        task.assignee = assignee.isEmpty ? nil : assignee
                        task.dueDate = dueDate
                        
                        // Parse tags
                        let tags = tagsText.split(separator: ",").map { tag in
                            tag.trimmingCharacters(in: .whitespaces)
                        }.filter { !$0.isEmpty }
                        task.tags = tags
                        
                        task.updatedAt = Date()
                        
                        // If status changed, move the task
                        if task.status != status {
                            KanbanState.shared.moveTask(task, from: task.status, to: status)
                        }
                        
                        onSave()
                        dismiss()
                    }
                }
            }
            .onAppear {
                title = task.title
                description = task.description
                status = task.status
                priority = task.priority
                assignee = task.assignee ?? ""
                dueDate = task.dueDate
            }
        }
    }
}

#Preview {
    TaskCardView(task: Task(
        title: "Sample Task",
        description: "This is a sample task description to demonstrate the task card view.",
        status: .inProgress,
        priority: .high,
        assignee: "John Doe",
        dueDate: Date().addingTimeInterval(86400 * 3), // 3 days from now
        tags: ["feature", "important"]
    ))
}