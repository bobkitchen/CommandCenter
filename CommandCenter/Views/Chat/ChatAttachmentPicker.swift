import SwiftUI
import PhotosUI

#if os(iOS)
struct ChatAttachmentPicker: View {
    @Binding var selectedImageData: Data?
    @Binding var selectedFileName: String?
    @Binding var isPresented: Bool

    @State private var showPhotoPicker = false
    @State private var showFilePicker = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        HStack(spacing: 16) {
            Button {
                showPhotoPicker = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3)
                    Text("Photo")
                        .font(.caption2)
                }
                .foregroundStyle(AppColors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColors.card, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Button {
                showFilePicker = true
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "doc")
                        .font(.title3)
                    Text("File")
                        .font(.caption2)
                }
                .foregroundStyle(AppColors.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(AppColors.card, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .photosPicker(isPresented: $showPhotoPicker, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) {
            Task {
                if let data = try? await photoItem?.loadTransferable(type: Data.self) {
                    selectedImageData = data
                    selectedFileName = nil
                    isPresented = false
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.text, .pdf, .image, .json, .plainText],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                selectedFileName = url.lastPathComponent
                selectedImageData = nil
                isPresented = false
            }
        }
    }
}
#endif
