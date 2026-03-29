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
    @State private var showShare = false
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

                #if os(iOS)
                // Invisible VC embedded in the sheet's own hierarchy
                if let tempFileURL {
                    SharePresenter(fileURL: tempFileURL, isPresented: $showShare)
                        .frame(width: 0, height: 0)
                        .allowsHitTesting(false)
                }
                #endif
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
                        showShare = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundStyle(AppColors.accent)
                    .disabled(tempFileURL == nil)
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
                    writeTempFile(data: data)
                }
            } else {
                textContent = response.content
                writeTempFile(text: response.content)
            }
        } catch {
            self.error = "Unable to load file"
        }
        isLoading = false
    }

    private func writeTempFile(data: Data? = nil, text: String? = nil) {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        do {
            if let data {
                try data.write(to: fileURL)
            } else if let text {
                try text.write(to: fileURL, atomically: true, encoding: .utf8)
            }
            tempFileURL = fileURL
        } catch {}
    }
}

// MARK: - iOS Share Presenter (UIKit-based, works inside sheets)

#if os(iOS)
struct SharePresenter: UIViewControllerRepresentable {
    let fileURL: URL
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ vc: UIViewController, context: Context) {
        if isPresented, vc.presentedViewController == nil {
            let activityVC = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )
            activityVC.popoverPresentationController?.sourceView = vc.view
            activityVC.popoverPresentationController?.sourceRect = .zero
            activityVC.completionWithItemsHandler = { _, _, _, _ in
                isPresented = false
            }
            vc.present(activityVC, animated: true)
        } else if !isPresented, vc.presentedViewController != nil {
            vc.dismiss(animated: true)
        }
    }
}
#endif

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
