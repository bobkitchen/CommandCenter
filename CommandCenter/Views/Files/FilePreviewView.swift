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
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.accent)
                }
                #else
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
}
