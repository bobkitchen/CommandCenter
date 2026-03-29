#if os(macOS)
import SwiftUI

struct FileManagerView: View {
    @State private var entries: [FileEntry] = []
    @State private var currentPath: [String] = []
    @State private var workspace = "main"
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var searchText = ""
    @State private var selectedFile: FileEntry?

    private let workspaces = ["main", "workspace-sentinel", "workspace-mirror", "workspace-scout"]

    private var filteredEntries: [FileEntry] {
        if searchText.isEmpty { return sortedEntries }
        return sortedEntries.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    private var sortedEntries: [FileEntry] {
        entries.sorted { a, b in
            if a.isDirectory != b.isDirectory { return a.isDirectory }
            return a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        }
    }

    private var selectedFilePath: String? {
        guard let file = selectedFile else { return nil }
        return (currentPath + [file.name]).joined(separator: "/")
    }

    var body: some View {
        HSplitView {
            // Left pane — file tree
            leftPane
                .frame(minWidth: 250, maxWidth: 320)

            // Right pane — editor/preview
            rightPane
                .frame(minWidth: 400, maxWidth: .infinity)
        }
        .task { await loadDirectory() }
    }

    // MARK: - Left Pane

    private var leftPane: some View {
        VStack(spacing: 0) {
            // Workspace picker
            workspacePicker
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 6)

            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppColors.muted)
                    .font(.caption)
                TextField("Filter files…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColors.muted)
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(AppColors.card)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .padding(.horizontal, 10)
            .padding(.bottom, 8)

            Divider()

            // File list
            fileList

            Divider()

            // Breadcrumb nav bar
            breadcrumbBar
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
        }
        .background(AppColors.background)
    }

    private var workspacePicker: some View {
        Picker("Workspace", selection: $workspace) {
            ForEach(workspaces, id: \.self) { ws in
                Text(displayName(for: ws)).tag(ws)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: workspace) {
            currentPath = []
            selectedFile = nil
            Task { await loadDirectory() }
        }
    }

    private var fileList: some View {
        Group {
            if isLoading {
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
            } else if let error = loadError {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(AppColors.warning)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(AppColors.muted)
                        .multilineTextAlignment(.center)
                    Button("Retry") { Task { await loadDirectory() } }
                        .font(.caption)
                    Spacer()
                }
                .padding()
            } else if filteredEntries.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: searchText.isEmpty ? "folder" : "magnifyingglass")
                        .font(.title2)
                        .foregroundStyle(AppColors.muted)
                    Text(searchText.isEmpty ? "Empty directory" : "No results")
                        .font(.caption)
                        .foregroundStyle(AppColors.muted)
                    Spacer()
                }
            } else {
                List(filteredEntries, selection: $selectedFile) { entry in
                    fileRow(entry)
                        .tag(entry)
                        .listRowBackground(
                            selectedFile?.id == entry.id
                                ? AppColors.accent.opacity(0.15)
                                : Color.clear
                        )
                        .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if entry.isDirectory {
                                selectedFile = nil
                                currentPath.append(entry.name)
                                Task { await loadDirectory() }
                            } else {
                                selectedFile = entry
                            }
                        }
                }
                .listStyle(.plain)
            }
        }
    }

    private func fileRow(_ entry: FileEntry) -> some View {
        HStack(spacing: 6) {
            Image(systemName: entry.icon)
                .font(.system(size: 12))
                .foregroundStyle(entry.isDirectory ? AppColors.accent : AppColors.muted)
                .frame(width: 16)

            Text(entry.name)
                .font(.system(size: 12))
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            let sizeStr = entry.formattedSize
            if !sizeStr.isEmpty {
                Text(sizeStr)
                    .font(.system(size: 10))
                    .foregroundStyle(AppColors.muted)
            }
        }
        .padding(.vertical, 1)
    }

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                Button("Root") {
                    currentPath = []
                    selectedFile = nil
                    Task { await loadDirectory() }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundStyle(currentPath.isEmpty ? AppColors.text : AppColors.accent)

                ForEach(Array(currentPath.enumerated()), id: \.offset) { idx, segment in
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9))
                        .foregroundStyle(AppColors.muted)

                    Button(segment) {
                        currentPath = Array(currentPath.prefix(idx + 1))
                        selectedFile = nil
                        Task { await loadDirectory() }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(
                        idx == currentPath.count - 1 ? AppColors.text : AppColors.accent
                    )
                }
            }
        }
    }

    // MARK: - Right Pane

    private var rightPane: some View {
        Group {
            if let file = selectedFile, let path = selectedFilePath {
                FileEditorView(
                    path: path,
                    workspace: workspace,
                    filename: file.name
                )
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundStyle(AppColors.muted)
                    Text("Select a file to preview")
                        .font(.title3)
                        .foregroundStyle(AppColors.muted)
                    if !currentPath.isEmpty {
                        Text(currentPath.joined(separator: " / "))
                            .font(.caption)
                            .foregroundStyle(AppColors.muted.opacity(0.6))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.backgroundGradient)
            }
        }
    }

    // MARK: - Helpers

    private func displayName(for workspace: String) -> String {
        switch workspace {
        case "main": return "Main"
        case "workspace-sentinel": return "Sentinel"
        case "workspace-mirror": return "Mirror"
        case "workspace-scout": return "Scout"
        default: return workspace.replacingOccurrences(of: "workspace-", with: "").capitalized
        }
    }

    // MARK: - Data loading

    private func loadDirectory() async {
        isLoading = true
        loadError = nil

        let sanitized = currentPath.filter { $0 != ".." && !$0.contains("/") }
        if sanitized.count != currentPath.count {
            currentPath = sanitized
        }

        let pathSuffix = currentPath.isEmpty ? "" : "/" + currentPath.joined(separator: "/")

        var queryItems = [URLQueryItem]()
        if workspace != "main" {
            queryItems.append(URLQueryItem(name: "workspace", value: workspace))
        }

        do {
            let response: DirectoryResponse = try await APIClient.shared.get(
                "/api/files\(pathSuffix)",
                queryItems: queryItems.isEmpty ? nil : queryItems
            )
            entries = response.entries
        } catch {
            entries = []
            loadError = "Unable to load directory"
        }

        isLoading = false
    }
}


#endif
