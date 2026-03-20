import Foundation

struct TaskItem: Codable, Identifiable, Equatable, Hashable {
    let id: String
    var title: String
    var description: String?
    var status: String
    var priority: String?
    var tags: [String]?
    var assignee: String?
    var createdAt: String?
    var updatedAt: String?
}

struct TasksResponse: Codable {
    let tasks: [TaskItem]
}

struct ColumnsResponse: Codable {
    let columns: [String]
}
