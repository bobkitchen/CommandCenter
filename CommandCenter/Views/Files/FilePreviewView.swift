import SwiftUI

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
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(AppColors.warning)
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.muted)
                    }
                } else if isImage, let imageData, let uiImage = UIImage(data: imageData) {
                    ScrollView {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .padding()
                    }
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(AppColors.accent)
                }
            }
        }
        .task { await loadFile() }
    }

    private func loadFile() async {
        var queryItems = [URLQueryItem(name: "content", value: "true")]
        if workspace != "workspace" {
            queryItems.append(URLQueryItem(name: "workspace", value: workspace))
        }
        do {
            let response: FileContentResponse = try await APIClient.shared.get(
                "/api/files/\(path)",
                queryItems: queryItems
            )
            if response.type == "image" {
                // Base64 data URL
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
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}
