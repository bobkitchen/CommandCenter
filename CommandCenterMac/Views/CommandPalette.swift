import SwiftUI

#if os(macOS)
struct PaletteCommand: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let shortcut: String?
    let navigate: SidebarItem?

    static var all: [PaletteCommand] {
        [
            PaletteCommand(title: "Dashboard", subtitle: "System overview and monitoring", icon: "square.grid.2x2", shortcut: "⌘1", navigate: .dashboard),
            PaletteCommand(title: "Chat with Denny", subtitle: "Open AI assistant chat", icon: "bubble.left.and.bubble.right", shortcut: "⌘2", navigate: .chat),
            PaletteCommand(title: "File Manager", subtitle: "Browse workspace files", icon: "folder", shortcut: "⌘3", navigate: .files),
            PaletteCommand(title: "Task Board", subtitle: "Kanban task management", icon: "rectangle.3.group", shortcut: "⌘4", navigate: .kanban),
            PaletteCommand(title: "Server Logs", subtitle: "Live-tail gateway and server logs", icon: "terminal", shortcut: "⌘5", navigate: .logs),
        ]
    }
}

struct CommandPalette: View {
    @Binding var selection: SidebarItem?
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @FocusState private var isFocused: Bool

    private var filteredCommands: [PaletteCommand] {
        if query.isEmpty { return PaletteCommand.all }
        return PaletteCommand.all.filter {
            $0.title.localizedCaseInsensitiveContains(query) ||
            $0.subtitle.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Type a command...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.title3)
                    .focused($isFocused)
                    .onSubmit {
                        if let first = filteredCommands.first {
                            execute(first)
                        }
                    }
                Button {
                    dismiss()
                } label: {
                    Text("ESC")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(filteredCommands) { cmd in
                        Button {
                            execute(cmd)
                        } label: {
                            HStack {
                                Image(systemName: cmd.icon)
                                    .frame(width: 24)
                                    .foregroundStyle(AppColors.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(cmd.title)
                                        .font(.body)
                                    Text(cmd.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if let shortcut = cmd.shortcut {
                                    Text(shortcut)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            .contentShape(Rectangle())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 350)
        }
        .frame(width: 500)
        .onAppear { isFocused = true }
    }

    private func execute(_ cmd: PaletteCommand) {
        if let nav = cmd.navigate {
            selection = nav
        }
        dismiss()
    }
}
#endif
