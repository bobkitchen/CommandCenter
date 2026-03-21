import SwiftUI

#if os(macOS)
struct MacContentView: View {
    @State private var selectedItem: SidebarItem? = .dashboard
    @State private var showCommandPalette = false

    var body: some View {
        NavigationSplitView {
            SidebarView(selection: $selectedItem)
                .frame(minWidth: 180)
        } detail: {
            Group {
                switch selectedItem {
                case .dashboard:
                    DashboardView()
                case .chat:
                    ChatView()
                case .files:
                    FileManagerView()
                case .kanban:
                    KanbanBoardView()
                case .logs:
                    LogsViewerView()
                case nil:
                    DashboardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showCommandPalette) {
            CommandPalette(selection: $selectedItem)
        }
        .background(
            Button("") { showCommandPalette = true }
                .keyboardShortcut("k", modifiers: .command)
                .hidden()
        )
    }

    private func placeholderView(_ title: String, icon: String, subtitle: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(AppColors.muted)
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(AppColors.text)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(AppColors.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundGradient)
    }
}
#endif
