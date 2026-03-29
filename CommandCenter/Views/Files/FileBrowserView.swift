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

                // Toast overlay
                if let toast = toastMessage {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding(.bottom, 30)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .allowsHitTesting(false)
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

        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }

            // First try the JSON content API (works for text and images)
            var queryItems = [URLQueryItem(name: "content", value: "true")]
            if workspace != "workspace" {
                queryItems.append(URLQueryItem(name: "workspace", value: workspace))
            }

            let response: FileContentResponse = try await APIClient.shared.get(
                "/api/files/\(sanitizedPath)",
                queryItems: queryItems
            )

            if let content = response.content, !content.isEmpty {
                if response.type == "image" {
                    let base64 = content
                        .replacingOccurrences(of: #"^data:[^;]+;base64,"#, with: "", options: .regularExpression)
                    if let data = Data(base64Encoded: base64) {
                        try data.write(to: destURL)
                    } else {
                        showToast("Failed to decode image")
                        return
                    }
                } else {
                    try content.write(to: destURL, atomically: true, encoding: .utf8)
                }
                showToast("Saved to Files")
            } else {
                // No inline content — try raw data download
                try await downloadRawFile(sanitizedPath: sanitizedPath, destURL: destURL)
            }
        } catch {
            // JSON decode failed — try raw data download as fallback
            do {
                try await downloadRawFile(sanitizedPath: sanitizedPath, destURL: destURL)
            } catch {
                showToast("Download failed")
            }
        }
    }

    private func downloadRawFile(sanitizedPath: String, destURL: URL) async throws {
        var queryItems = [URLQueryItem(name: "raw", value: "true")]
        if workspace != "workspace" {
            queryItems.append(URLQueryItem(name: "workspace", value: workspace))
        }

        let data = try await APIClient.shared.getData(
            "/api/files/\(sanitizedPath)",
            queryItems: queryItems
        )

        guard !data.isEmpty else {
            showToast("Empty file")
            return
        }

        // Check if the response is actually a JSON error instead of raw file data
        if data.count < 500, let text = String(data: data, encoding: .utf8),
           text.trimmingCharacters(in: .whitespaces).hasPrefix("{") {
            // Server returned JSON, not raw file — save as text
            try data.write(to: destURL)
        } else {
            try data.write(to: destURL)
        }

        showToast("Saved to Files")
    }

    @MainActor
    private func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { toastMessage = nil }
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
