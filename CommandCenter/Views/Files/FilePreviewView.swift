import SwiftUI
import UniformTypeIdentifiers
#if os(macOS)
import AppKit
#endif

struct FilePreviewView: View {
    let path: String
    let workspace: String
    let filename: String

    @State private var textContent: String?
    @State private var imageData: Data?
    @State private var isImage = false
    @State private var isLoading = true
    @State private var error: String?
    @State private var showExporter = false
    @State private var exportDocument: ExportFileDocument?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.backgroundGradient

                if isLoading {
                    ProgressView("Loading…")
                        .foregroundStyle(AppColors.muted)
                } else if let error {
                    ErrorRetryView(message: error) {
                        Task { await loadFile() }
                    }
                } else if isImage, let imageData {
                    #if os(iOS)
                    if let uiImage = UIImage(data: imageData) {
                        ScrollView {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .padding()
                        }
                    }
                    #elseif os(macOS)
                    if let nsImage = NSImage(data: imageData) {
                        ScrollView {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFit()
                                .padding()
                        }
                    }
                    #endif
                } else if let textContent {
                    ScrollView {
                        VStack(alignment: .leading) {
                            if filename.hasSuffix(".md") {
                                MarkdownText(textContent)
                            } else {
                                Text(textContent)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(AppColors.text)
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .navigationTitle(filename)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        if let exportDocument {
                            self.exportDocument = exportDocument
                            showExporter = true
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundStyle(AppColors.accent)
                    .disabled(exportDocument == nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.accent)
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button {
                        saveFileAs()
                    } label: {
                        Label("Save As…", systemImage: "square.and.arrow.down")
                    }
                    .foregroundStyle(AppColors.accent)
                    .disabled(isLoading || (textContent == nil && imageData == nil))
                }
                ToolbarItem(placement: .automatic) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.accent)
                }
                #endif
            }
            .fileExporter(
                isPresented: $showExporter,
                document: exportDocument,
                contentType: exportContentType,
                defaultFilename: filename
            ) { _ in }
        }
        .task { await loadFile() }
    }

    private var exportContentType: UTType {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "png": return .png
        case "jpg", "jpeg": return .jpeg
        case "gif": return .gif
        case "json": return .json
        case "pdf": return .pdf
        case "txt": return .plainText
        case "md": return .plainText
        default: return .data
        }
    }

    private func loadFile() async {
        isLoading = true
        error = nil

        let components = path.components(separatedBy: "/")
        guard components.allSatisfy({ $0 != ".." }) else {
            error = "Invalid file path"
            isLoading = false
            return
        }

        let sanitizedPath = components
            .map { $0.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? $0 }
            .joined(separator: "/")

        var queryItems = [URLQueryItem(name: "content", value: "true")]
        if workspace != "workspace" {
            queryItems.append(URLQueryItem(name: "workspace", value: workspace))
        }
        do {
            let response: FileContentResponse = try await APIClient.shared.get(
                "/api/files/\(sanitizedPath)",
                queryItems: queryItems
            )
            if response.type == "image" {
                let base64 = response.content
                    .replacingOccurrences(of: #"^data:[^;]+;base64,"#, with: "", options: .regularExpression)
                if let data = Data(base64Encoded: base64) {
                    imageData = data
                    isImage = true
                    exportDocument = ExportFileDocument(data: data)
                }
            } else {
                textContent = response.content
                if let data = response.content.data(using: .utf8) {
                    exportDocument = ExportFileDocument(data: data)
                }
            }
        } catch {
            self.error = "Unable to load file"
        }
        isLoading = false
    }
}

// MARK: - Export Document

struct ExportFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    let data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - macOS Save As

extension FilePreviewView {
    #if os(macOS)
    func saveFileAs() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = filename
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            do {
                if isImage, let imageData {
                    try imageData.write(to: url)
                } else if let textContent {
                    try textContent.write(to: url, atomically: true, encoding: .utf8)
                }
            } catch {}
        }
    }
    #endif
}
