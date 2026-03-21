import SwiftUI

struct AttachmentPreview: View {
    let imageData: Data?
    let fileName: String?
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            #if os(iOS)
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            #elseif os(macOS)
            if let data = imageData, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            #endif

            if let name = fileName {
                HStack(spacing: 6) {
                    Image(systemName: "doc.fill")
                        .font(.caption)
                        .foregroundStyle(AppColors.accent)
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(AppColors.text)
                        .lineLimit(1)
                }
            } else if imageData != nil {
                Text("Photo attached")
                    .font(.caption)
                    .foregroundStyle(AppColors.text)
            }

            Spacer()

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppColors.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(AppColors.card.opacity(0.8), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 12)
    }
}
