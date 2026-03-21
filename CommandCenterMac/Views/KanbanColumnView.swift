import SwiftUI

#if os(macOS)
struct KanbanColumnView: View {
    let title: String
    let tasks: [TaskItem]
    let columns: [String]
    let onStatusChange: (TaskItem, String) -> Void
    let onDelete: (TaskItem) -> Void
    let lookupTask: (String) -> TaskItem?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Text("\(tasks.count)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(tasks) { task in
                        KanbanCardView(task: task, columns: columns) { newStatus in
                            onStatusChange(task, newStatus)
                        } onDelete: {
                            onDelete(task)
                        }
                    }
                }
                .padding(8)
            }
            .dropDestination(for: String.self) { droppedIds, _ in
                for id in droppedIds {
                    if let task = lookupTask(id) {
                        onStatusChange(task, title)
                    }
                }
                return true
            }
        }
        .background(AppColors.background.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.border, lineWidth: 0.5))
    }
}
#endif
