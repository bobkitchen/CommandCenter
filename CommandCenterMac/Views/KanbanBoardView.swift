import SwiftUI

#if os(macOS)
struct KanbanBoardView: View {
    @State private var taskService = TaskService()
    @State private var showNewTask = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Task Board")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    showNewTask = true
                } label: {
                    Label("New Task", systemImage: "plus")
                }

                Button {
                    Task { await taskService.loadTasks() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .padding()

            if let error = taskService.error {
                Text(error)
                    .foregroundStyle(AppColors.danger)
                    .font(.caption)
                    .padding(.horizontal)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(taskService.columns, id: \.self) { column in
                        KanbanColumnView(
                            title: column,
                            tasks: taskService.tasksForColumn(column),
                            columns: taskService.columns,
                            onStatusChange: { task, newStatus in
                                Task { await taskService.updateTaskStatus(task, newStatus: newStatus) }
                            },
                            onDelete: { task in
                                Task { await taskService.deleteTask(task) }
                            },
                            lookupTask: { id in
                                taskService.tasks.first(where: { $0.id == id })
                            }
                        )
                        .frame(minWidth: 200)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
        .background(AppColors.backgroundGradient)
        .task {
            await taskService.loadColumns()
            await taskService.loadTasks()
        }
        .sheet(isPresented: $showNewTask) {
            NewTaskSheet(columns: taskService.columns) { title, desc, column, priority in
                Task {
                    await taskService.createTask(title: title, description: desc, status: column, priority: priority)
                }
            }
        }
    }
}

struct NewTaskSheet: View {
    let columns: [String]
    let onCreate: (String, String?, String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var description = ""
    @State private var column = "to_do"
    @State private var priority = "medium"

    var body: some View {
        VStack(spacing: 16) {
            Text("New Task")
                .font(.headline)

            TextField("Task title", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("Description (optional)", text: $description, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3...6)

            Picker("Column", selection: $column) {
                ForEach(columns, id: \.self) { col in
                    Text(col).tag(col.lowercased().replacingOccurrences(of: " ", with: "_"))
                }
            }

            Picker("Priority", selection: $priority) {
                Text("Low").tag("low")
                Text("Medium").tag("medium")
                Text("High").tag("high")
                Text("Critical").tag("critical")
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Create") {
                    let desc = description.isEmpty ? nil : description
                    onCreate(title, desc, column, priority)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }
}
#endif
