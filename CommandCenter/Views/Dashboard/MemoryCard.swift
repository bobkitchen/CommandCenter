import SwiftUI

struct MemoryEntry: Codable, Identifiable {
    let name: String
    let type: String
    let size: Int?
    let modified: String?
    let `extension`: String?

    var id: String { name }

    var isMemoryFile: Bool {
        name.hasSuffix(".md") || name.hasSuffix(".txt") || name.hasSuffix(".json")
    }

    var icon: String {
        switch name.lowercased() {
        case let n where n.contains("soul"): return "sparkles"
        case let n where n.contains("context"): return "brain.head.profile"
        case let n where n.contains("preference"): return "slider.horizontal.3"
        case let n where n.contains("schedule"): return "calendar"
        default: return "doc.text"
        }
    }
}

struct MemoryListResponse: Codable {
    let path: String?
    let workspace: String?
    let entries: [MemoryEntry]
}

struct MemoryCard: View {
    @State private var entries: [MemoryEntry] = []
    @State private var isLoading = true
    @State private var loadError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Denny's Memory", systemImage: "brain")
                    .font(.headline)
                    .foregroundStyle(.purple)

                Spacer()

                Text("\(entries.count) files")
                    .font(.caption2)
                    .foregroundStyle(AppColors.muted)
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if loadError {
                ErrorRetryView(message: "Unable to load memory") {
                    Task { await loadMemory() }
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else if entries.isEmpty {
                Text("No memory files found")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.muted)
            } else {
                VStack(spacing: 6) {
                    ForEach(entries.prefix(6)) { entry in
                        HStack(spacing: 8) {
                            Image(systemName: entry.icon)
                                .font(.caption)
                                .foregroundStyle(.purple.opacity(0.8))
                                .frame(width: 16)

                            Text(entry.name)
                                .font(.caption)
                                .foregroundStyle(AppColors.text)
                                .lineLimit(1)

                            Spacer()

                            if let size = entry.size {
                                Text(formatSize(size))
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppColors.muted)
                            }

                            if let modified = entry.modified {
                                Text(formatRelativeDate(modified))
                                    .font(.system(size: 9))
                                    .foregroundStyle(AppColors.muted)
                            }
                        }
                    }

                    if entries.count > 6 {
                        Text("+\(entries.count - 6) more")
                            .font(.caption2)
                            .foregroundStyle(AppColors.muted)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(tint: .purple.opacity(0.06))
        .task { await loadMemory() }
    }

    private func loadMemory() async {
        isLoading = true
        loadError = false
        do {
            let response: MemoryListResponse = try await APIClient.shared.get("/api/files/memory")
            entries = response.entries.filter { $0.isMemoryFile }
                .sorted { ($0.modified ?? "") > ($1.modified ?? "") }
        } catch {
            loadError = true
        }
        isLoading = false
    }

    private func formatSize(_ bytes: Int) -> String {
        if bytes >= 1_048_576 { return String(format: "%.1fMB", Double(bytes) / 1_048_576) }
        if bytes >= 1024 { return String(format: "%.0fKB", Double(bytes) / 1024) }
        return "\(bytes)B"
    }

    private func formatRelativeDate(_ dateStr: String) -> String {
        guard let date = DateFormatters.parseDate(from: dateStr) else { return "" }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86400)d ago"
    }
}
