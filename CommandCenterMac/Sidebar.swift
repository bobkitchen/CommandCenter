import SwiftUI

#if os(macOS)
enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "Dashboard"
    case chat = "Chat"
    case files = "Files"
    case kanban = "Tasks"
    case logs = "Logs"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .chat: return "bubble.left.and.bubble.right"
        case .files: return "folder"
        case .kanban: return "rectangle.3.group"
        case .logs: return "terminal"
        }
    }
}

struct SidebarView: View {
    @Binding var selection: SidebarItem?

    var body: some View {
        List(SidebarItem.allCases, selection: $selection) { item in
            Label(item.rawValue, systemImage: item.icon)
                .tag(item)
        }
        .listStyle(.sidebar)
        .navigationTitle("Command Center")
    }
}
#endif
