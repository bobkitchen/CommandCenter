import Foundation

struct FileEntry: Codable, Identifiable, Hashable {
    let name: String
    let type: String        // "file" or "directory"
    let size: Int?
    let modified: String?
    let extension_: String?

    var id: String { name }
    var isDirectory: Bool { type == "directory" || type == "dir" }

    var formattedSize: String {
        guard !isDirectory, let size else { return "" }
        if size < 1024 { return "\(size) B" }
        if size < 1024 * 1024 { return "\(size / 1024) KB" }
        return String(format: "%.1f MB", Double(size) / (1024 * 1024))
    }

    var icon: String {
        if isDirectory { return "folder.fill" }
        guard let ext = extension_?.lowercased() else { return "doc" }
        switch ext {
        case "md": return "doc.text"
        case "swift", "js", "ts", "py", "json": return "chevron.left.forwardslash.chevron.right"
        case "png", "jpg", "jpeg", "gif", "webp": return "photo"
        case "pdf": return "doc.richtext"
        default: return "doc"
        }
    }

    enum CodingKeys: String, CodingKey {
        case name, type, size, modified
        case extension_ = "extension"
    }
}

struct DirectoryResponse: Codable {
    let path: String?
    let workspace: String?
    let entries: [FileEntry]
}

struct FileContentResponse: Codable {
    let type: String        // "text" or "image"
    let content: String
    let filename: String?
    let size: Int?
}
