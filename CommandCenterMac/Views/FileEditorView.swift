#if os(macOS)
import SwiftUI
import AppKit

struct FileEditorView: View {
    let path: String
    let workspace: String
    let filename: String

    @State private var textContent: String = ""
    @State private var editBuffer: String = ""
    @State private var imageData: Data?
    @State private var isImage = false
    @State private var isLoading = true
    @State private var isEditing = false
    @State private var loadError: String?

    private var isMarkdown: Bool { filename.hasSuffix(".md") }
    private var canEdit: Bool { !isImage }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.card)

            Divider()

            contentArea
        }
        .background(AppColors.backgroundGradient)
        .task(id: path) { await loadFile() }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: fileIcon)
                .foregroundStyle(AppColors.muted)
                .font(.body)

            Text(filename)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppColors.text)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer()

            if canEdit && !isLoading && loadError == nil {
                Button {
                    if isEditing {
                        // Discard — revert to original
                        isEditing = false
                        editBuffer = textContent
                    } else {
                        editBuffer = textContent
                        isEditing = true
                    }
                } label: {
                    Label(isEditing ? "Cancel" : "Edit", systemImage: isEditing ? "xmark" : "pencil")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            Button {
                saveFileAs()
            } label: {
                Label("Save As…", systemImage: "square.and.arrow.down")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isLoading || loadError != nil || (textContent.isEmpty && imageData == nil))

            Button {
                isEditing = false
                Task { await loadFile() }
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(isLoading)
        }
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView("Loading…")
                    .foregroundStyle(AppColors.muted)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = loadError {
            VStack(spacing: 12) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(AppColors.warning)
                Text(error)
                    .foregroundStyle(AppColors.muted)
                Button("Retry") { Task { await loadFile() } }
                    .buttonStyle(.bordered)
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if isImage, let imageData, let nsImage = NSImage(data: imageData) {
            imageViewer(nsImage)
        } else if isEditing {
            editorView
        } else {
            readView
        }
    }

    private func imageViewer(_ nsImage: NSImage) -> some View {
        ScrollView([.horizontal, .vertical]) {
            Image(nsImage: nsImage)
                .resizable()
                .scaledToFit()
                .padding(16)
                .frame(maxWidth: .infinity)
        }
    }

    private var readView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if isMarkdown {
                    MarkdownText(textContent)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(textContent)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(AppColors.text)
                        .textSelection(.enabled)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var editorView: some View {
        TextEditor(text: $editBuffer)
            .font(.system(.body, design: .monospaced))
            .foregroundStyle(AppColors.text)
            .scrollContentBackground(.hidden)
            .background(AppColors.background)
            .padding(12)
    }

    // MARK: - File icon

    private var fileIcon: String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "md": return "doc.text"
        case "swift", "js", "ts", "py", "json":
            return "chevron.left.forwardslash.chevron.right"
        case "png", "jpg", "jpeg", "gif", "webp":
            return "photo"
        case "pdf": return "doc.richtext"
        default: return "doc"
        }
    }

    // MARK: - Save As

    private func saveFileAs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                if isImage, let imageData {
                    try imageData.write(to: url)
                } else {
                    let content = isEditing ? editBuffer : textContent
                    try content.write(to: url, atomically: true, encoding: .utf8)
                }
            } catch {
                // Panel handles permission errors
            }
        }
    }

    // MARK: - Data loading

    private func loadFile() async {
        isLoading = true
        loadError = nil
        isImage = false
        imageData = nil
        textContent = ""
        isEditing = false

        let components = path.components(separatedBy: "/")
        guard components.allSatisfy({ $0 != ".." }) else {
            loadError = "Invalid file path"
            isLoading = false
            return
        }

        let sanitizedPath = components
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0 }
            .joined(separator: "/")

        var queryItems = [URLQueryItem(name: "content", value: "true")]
        if workspace != "main" {
            queryItems.append(URLQueryItem(name: "workspace", value: workspace))
        }

        do {
            let response: FileContentResponse = try await APIClient.shared.get(
                "/api/files/\(sanitizedPath)",
                queryItems: queryItems
            )

            if let serverError = response.error {
                loadError = serverError
            } else if response.type == "image", let content = response.content {
                let base64 = content
                    .replacingOccurrences(of: #"^data:[^;]+;base64,"#, with: "", options: .regularExpression)
                if let data = Data(base64Encoded: base64) {
                    imageData = data
                    isImage = true
                } else {
                    loadError = "Unable to decode image"
                }
            } else if let content = response.content, !content.isEmpty {
                textContent = content
                editBuffer = content
            } else {
                let fileType = response.type ?? response.mimeType ?? "binary"
                loadError = "Cannot preview \(fileType) files"
            }
        } catch {
            loadError = "Unable to load file"
        }

        isLoading = false
    }
}
#endif
