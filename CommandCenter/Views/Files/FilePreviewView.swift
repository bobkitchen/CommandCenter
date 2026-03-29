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
    @State private var tempFileURL: URL?
    @State private var savedAlert = false
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
                        saveToDocuments()
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .foregroundStyle(AppColors.accent)
                    .disabled(textContent == nil && imageData == nil)
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
            #if os(iOS)
            .alert("Saved", isPresented: $savedAlert) {
                Button("OK") {}
            } message: {
                Text("Saved to Files → On My iPhone → CommandCenter")
            }
            #endif
        }
        .task { await loadFile() }
    }

    #if os(iOS)
    private func saveToDocuments() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let destURL = docs.appendingPathComponent(filename)
        do {
            // Remove existing file with same name
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            if isImage, let imageData {
                try imageData.write(to: destURL)
            } else if let textContent {
                try textContent.write(to: destURL, atomically: true, encoding: .utf8)
            }
            savedAlert = true
        } catch {
            self.error = "Failed to save: \(error.localizedDescription)"
        }
    }
    #endif

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
