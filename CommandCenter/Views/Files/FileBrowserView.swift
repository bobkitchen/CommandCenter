import SwiftUI

struct FileBrowserView: View {
    @State private var entries: [FileEntry] = []
    @State private var currentPath: [String] = []
    @State private var workspace = "workspace"
    @State private var isLoading = true
    @State private var selectedFile: FileEntry?
    @State private var searchText = ""
    @State private var loadError: String?

    private let workspaces = ["workspace", "workspace-sentinel", "workspace-mirror", "workspace-scout"]

    private var filteredEntries: [FileEntry] {
        if searchText.isEmpty { return entries }
        return entries.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGradient

                VStack(spacing: 0) {
                    // Workspace picker + breadcrumbs
                    VStack(spacing: 8) {
                        HStack {
                            Menu {
                                ForEach(workspaces, id: \.self) { ws in
                                    Button(ws.replacingOccurrences(of: "workspace-", with: "").capitalized) {
                                        workspace = ws
                                        currentPath = []
                                        Task { await loadDirectory() }
                                    }
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder.badge.gearshape")
                                    Text(workspace.replacingOccurrences(of: "workspace-", with: "").capitalized)
                                        .font(.subheadline.weight(.medium))
                                    Image(systemName: "chevron.down")
                                        .font(.caption)
                                }
                                .foregroundStyle(AppColors.accent)
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)

                        if !currentPath.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    Button("Root") {
                                        currentPath = []
                                        Task { await loadDirectory() }
                                    }
                                    .font(.caption)
                                    .foregroundStyle(AppColors.accent)

                                    ForEach(Array(currentPath.enumerated()), id: \.offset) { idx, segment in
                                        Image(systemName: "chevron.right")
                                            .font(.caption2)
                                            .foregroundStyle(AppColors.muted)

                                        Button(segment) {
                                            currentPath = Array(currentPath.prefix(idx + 1))
                                            Task { await loadDirectory() }
                                        }
                                        .font(.caption)
                                        .foregroundStyle(idx == currentPath.count - 1 ? AppColors.text : AppColors.accent)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)

                    // File list
                    if isLoading {
                        Spacer()
                        ProgressView()
                        Spacer()
                    } else if let error = loadError {
                        Spacer()
                        ErrorRetryView(message: error) {
                            Task { await loadDirectory() }
                        }
                        Spacer()
                    } else if entries.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "folder")
                                .font(.largeTitle)
                                .foregroundStyle(AppColors.muted)
                            Text("Empty directory")
                                .foregroundStyle(AppColors.muted)
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(filteredEntries) { entry in
                                FileRow(entry: entry)
                                    .listRowBackground(Color.clear)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        HapticHelper.light()
                                        if entry.isDirectory {
                                            currentPath.append(entry.name)
                                            Task { await loadDirectory() }
                                        } else {
                                            selectedFile = entry
                                        }
                                    }
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .refreshable { await loadDirectory() }
                    }
                }
            }
            .navigationTitle("Files")
            #if os(iOS)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .searchable(text: $searchText, prompt: "Filter files")
            .sheet(item: $selectedFile) { file in
                FilePreviewView(
                    path: (currentPath + [file.name]).joined(separator: "/"),
                    workspace: workspace,
                    filename: file.name
                )
            }
        }
        .task { await loadDirectory() }
    }

    private func loadDirectory() async {
        isLoading = true
        loadError = nil

        // Sanitize path components
        let sanitized = currentPath.filter { $0 != ".." && !$0.contains("/") }
        if sanitized.count != currentPath.count {
            currentPath = sanitized
        }

        let path = currentPath.isEmpty ? "" : "/" + currentPath.joined(separator: "/")
        var queryItems = [URLQueryItem]()
        if workspace != "workspace" {
            queryItems.append(URLQueryItem(name: "workspace", value: workspace))
        }
        do {
            let response: DirectoryResponse = try await APIClient.shared.get(
                "/api/files\(path)",
                queryItems: queryItems.isEmpty ? nil : queryItems
            )
            entries = response.entries.sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory }
                return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
            }
        } catch {
            entries = []
            loadError = "Unable to load files"
        }
        isLoading = false
    }
}
