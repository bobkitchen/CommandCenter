import Foundation

@MainActor @Observable
final class TaskService {
    var tasks: [TaskItem] = []
    var columns: [String] = ["Backlog", "To Do", "In Progress", "Review", "Done"]
    var isLoading = false
    var error: String?

    func loadTasks() async {
        isLoading = true
        do {
            let response: TasksResponse = try await APIClient.shared.get("/api/tasks")
            tasks = response.tasks
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    func loadColumns() async {
        do {
            let response: ColumnsResponse = try await APIClient.shared.get("/api/tasks/columns")
            columns = response.columns
        } catch {
            // Use defaults silently
        }
    }

    func createTask(title: String, description: String?, status: String, priority: String?) async {
        var body: [String: Any] = ["title": title, "status": status]
        if let desc = description { body["description"] = desc }
        if let pri = priority { body["priority"] = pri }
        do {
            let _: TaskItem = try await APIClient.shared.post("/api/tasks", body: body)
            await loadTasks()
        } catch {
            self.error = error.localizedDescription
        }
    }

    func updateTaskStatus(_ task: TaskItem, newStatus: String) async {
        let normalizedStatus = newStatus.lowercased().replacingOccurrences(of: " ", with: "_")
        // Optimistic update
        if let idx = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[idx].status = normalizedStatus
        }
        do {
            try await APIClient.shared.postAction(
                "/api/tasks/\(task.id)",
                body: ["status": normalizedStatus]
            )
        } catch {
            self.error = error.localizedDescription
            await loadTasks()
        }
    }

    func deleteTask(_ task: TaskItem) async {
        tasks.removeAll { $0.id == task.id }
        do {
            try await APIClient.shared.postAction("/api/tasks/\(task.id)/delete")
        } catch {
            self.error = error.localizedDescription
            await loadTasks()
        }
    }

    func tasksForColumn(_ column: String) -> [TaskItem] {
        let status = column.lowercased().replacingOccurrences(of: " ", with: "_")
        return tasks.filter { $0.status == status }
    }
}
