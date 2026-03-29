import SwiftUI

struct FileBrowserView: View {
    @State private var entries: [FileEntry] = []
    @State private var currentPath: [String] = []
    @State private var workspace = "workspace"
    @State private var isLoading = true
    @State private var selectedFile: FileEntry?
    @State private var searchText = ""
    @State private var loadError: String?
    @State private var toastMessage: String?
    @State private var downloadState: DownloadState = .idle

    enum DownloadState: Equatable {
        case idle
        case downloading(filename: String, bytesWritten: Int64, totalBytes: Int64)
        case completed(filename: String, fileSize: Int64)
        case failed(String)
    }

    private let workspaces = ["workspace", "workspace-sentinel", "workspace-mirror", "workspace-scout"]

    // .urlPathAllowed leaves & + = ? # unencoded — they break URL parsing
    private static let safePathCharacters: CharacterSet = {
        var set = CharacterSet.urlPathAllowed
        set.remove(charactersIn: "&+=?#")
        return set
    }()

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
                                    #if os(iOS)
                                    .contextMenu {
                                        if !entry.isDirectory {
                                            Button {
                                                Task { await downloadFile(entry) }
                                            } label: {
                                                Label("Save to Device", systemImage: "square.and.arrow.down")
                                            }
                                        }
                                    }
                                    #endif
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .refreshable { await loadDirectory() }
                    }
                }

                // Download overlay
                if downloadState != .idle {
                    VStack {
                        Spacer()
                        downloadOverlay
                            .padding(.horizontal, 20)
                            .padding(.bottom, 30)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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

    // MARK: - Download overlay

    @ViewBuilder
    private var downloadOverlay: some View {
        VStack(spacing: 10) {
            switch downloadState {
            case .idle:
                EmptyView()

            case .downloading(let filename, let bytesWritten, let totalBytes):
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(.white)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(filename)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        if totalBytes > 0 {
                            ProgressView(value: Double(bytesWritten), total: Double(totalBytes))
                                .tint(AppColors.accent)
                            Text("\(formatBytes(bytesWritten)) / \(formatBytes(totalBytes))")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        } else {
                            Text("Downloading… \(formatBytes(bytesWritten))")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))

            case .completed(let filename, let fileSize):
                VStack(spacing: 6) {
                    Label("Downloaded", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.green)
                    Text("\(filename) (\(formatBytes(fileSize)))")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text("Files → On My iPhone → CommandCenter")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.5))
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .onTapGesture {
                    withAnimation { downloadState = .idle }
                }

            case .failed(let message):
                VStack(spacing: 4) {
                    Label("Download Failed", systemImage: "xmark.circle.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .onTapGesture {
                    withAnimation { downloadState = .idle }
                }
            }
        }
    }

    private func formatBytes(_ bytes: Int64) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.0f KB", Double(bytes) / 1024) }
        return String(format: "%.1f MB", Double(bytes) / (1024 * 1024))
    }

    // MARK: - Download file to Documents

    #if os(iOS)
    private func downloadFile(_ entry: FileEntry) async {
        let filePath = (currentPath + [entry.name]).joined(separator: "/")
        let components = filePath.components(separatedBy: "/")

        guard components.allSatisfy({ $0 != ".." }) else { return }

        let sanitizedPath = components
            .map { $0.addingPercentEncoding(withAllowedCharacters: Self.safePathCharacters) ?? $0 }
            .joined(separator: "/")

        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let destURL = docs.appendingPathComponent(entry.name)

        withAnimation { downloadState = .downloading(filename: entry.name, bytesWritten: 0, totalBytes: 0) }

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }

            // Use ?download=true for raw binary download with progress
            var queryItems = [URLQueryItem(name: "download", value: "true")]
            if workspace != "workspace" {
                queryItems.append(URLQueryItem(name: "workspace", value: workspace))
            }

            try await APIClient.shared.download(
                "/api/files/\(sanitizedPath)",
                queryItems: queryItems,
                to: destURL
            ) { bytesWritten, totalBytes in
                Task { @MainActor in
                    downloadState = .downloading(
                        filename: entry.name,
                        bytesWritten: bytesWritten,
                        totalBytes: totalBytes
                    )
                }
            }

            // Verify the file was actually saved
            let attrs = try FileManager.default.attributesOfItem(atPath: destURL.path)
            let fileSize = (attrs[.size] as? Int64) ?? 0

            if fileSize < 100 {
                // Probably a JSON error response, not a real file
                if let text = try? String(contentsOf: destURL, encoding: .utf8),
                   text.trimmingCharacters(in: .whitespaces).hasPrefix("{") {
                    try? FileManager.default.removeItem(at: destURL)
                    withAnimation { downloadState = .failed("Server returned error instead of file") }
                    autoDismissDownload()
                    return
                }
            }

            withAnimation { downloadState = .completed(filename: entry.name, fileSize: fileSize) }
            autoDismissDownload(delay: 5)

        } catch {
            withAnimation { downloadState = .failed(error.localizedDescription) }
            autoDismissDownload()
        }
    }

    private func autoDismissDownload(delay: Int = 3) {
        Task {
            try? await Task.sleep(for: .seconds(delay))
            withAnimation { downloadState = .idle }
        }
    }
    #endif

    // MARK: - Load directory

    private func loadDirectory() async {
        isLoading = true
        loadError = nil

        // Sanitize path components
        let sanitized = currentPath.filter { $0 != ".." && !$0.contains("/") }
        if sanitized.count != currentPath.count {
            currentPath = sanitized
        }

        let pathComponents = currentPath
            .map { $0.addingPercentEncoding(withAllowedCharacters: Self.safePathCharacters) ?? $0 }
        let path = pathComponents.isEmpty ? "" : "/" + pathComponents.joined(separator: "/")

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
