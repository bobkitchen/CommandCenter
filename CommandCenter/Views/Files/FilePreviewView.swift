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
    @State private var saveState: SaveState = .idle
    @Environment(\.dismiss) private var dismiss

    enum SaveState {
        case idle, saved, failed(String)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Content area
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

                #if os(iOS)
                // Bottom bar with save button — NOT in toolbar
                if !isLoading && error == nil && (textContent != nil || imageData != nil) {
                    HStack {
                        saveButton
                        Spacer()
                        Button("Done") { dismiss() }
                            .font(.body.weight(.medium))
                            .foregroundStyle(AppColors.accent)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(AppColors.card)
                }
                #endif
            }
            .navigationTitle(filename)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            #endif
            #if os(macOS)
            .toolbar {
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
            }
            #endif
        }
        .task { await loadFile() }
    }

    #if os(iOS)
    @ViewBuilder
    private var saveButton: some View {
        switch saveState {
        case .idle:
            Button {
                performSave()
            } label: {
                Label("Save to Device", systemImage: "square.and.arrow.down")
                    .font(.body.weight(.medium))
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.accent)
        case .saved:
            Label("Saved", systemImage: "checkmark.circle.fill")
                .font(.body.weight(.medium))
                .foregroundStyle(.green)
        case .failed(let msg):
            Label(msg, systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private func performSave() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            saveState = .failed("No documents directory")
            return
        }
        let destURL = docs.appendingPathComponent(filename)
        do {
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            if isImage, let imageData {
                try imageData.write(to: destURL)
            } else if let textContent {
                try textContent.write(to: destURL, atomically: true, encoding: .utf8)
            } else {
                saveState = .failed("No content")
                return
            }
            saveState = .saved
        } catch {
            saveState = .failed("Save failed")
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
