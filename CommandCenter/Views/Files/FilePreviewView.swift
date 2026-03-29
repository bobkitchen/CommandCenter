import SwiftUI
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
    @State private var showShareSheet = false
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
                        shareFile()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundStyle(AppColors.accent)
                    .disabled(isLoading || (textContent == nil && imageData == nil))
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
        }
        .task { await loadFile() }
    }

    private func loadFile() async {
        isLoading = true
        error = nil

        // Sanitize path — reject traversal attempts
        let components = path.components(separatedBy: "/")
        guard components.allSatisfy({ !$0.contains("..") }) else {
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
                }
            } else {
                textContent = response.content
            }
        } catch {
            self.error = "Unable to load file"
        }
        isLoading = false
    }

    private func writeTempFile() -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            if isImage, let imageData {
                try imageData.write(to: fileURL)
            } else if let textContent {
                try textContent.write(to: fileURL, atomically: true, encoding: .utf8)
            } else {
                return nil
            }
            return fileURL
        } catch {
            return nil
        }
    }

    #if os(iOS)
    private func shareFile() {
        guard let fileURL = writeTempFile() else { return }
        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        // Find the topmost presented controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController { topVC = presented }
        activityVC.popoverPresentationController?.sourceView = topVC.view
        activityVC.popoverPresentationController?.sourceRect = CGRect(x: topVC.view.bounds.midX, y: 60, width: 0, height: 0)
        topVC.present(activityVC, animated: true)
    }
    #endif

    #if os(macOS)
    private func saveFileAs() {
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
            } catch {
                // Silently fail — the panel already handles permission errors
            }
        }
    }
    #endif
}
