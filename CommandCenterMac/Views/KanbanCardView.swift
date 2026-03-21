import SwiftUI

#if os(macOS)
struct KanbanCardView: View {
    let task: TaskItem
    let columns: [String]
    let onStatusChange: (String) -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                if let priority = task.priority {
                    Circle()
                        .fill(priorityColor(priority))
                        .frame(width: 8, height: 8)
                        .padding(.top, 4)
                }
                Text(task.title)
                    .font(.body.weight(.medium))
                    .lineLimit(2)
            }

            if let desc = task.description, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            if let tags = task.tags, !tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.accent.opacity(0.2), in: Capsule())
                    }
                }
            }

            HStack {
                if let assignee = task.assignee {
                    Text(assignee)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
        .padding(10)
        .background(AppColors.card, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppColors.border, lineWidth: 0.5))
        .contextMenu {
            ForEach(columns, id: \.self) { col in
                Button("Move to \(col)") { onStatusChange(col) }
            }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
        .draggable(task.id)
    }

    private func priorityColor(_ p: String) -> Color {
        switch p {
        case "critical": return AppColors.danger
        case "high": return AppColors.warning
        case "medium": return AppColors.accent
        default: return AppColors.muted
        }
    }
}
#endif
