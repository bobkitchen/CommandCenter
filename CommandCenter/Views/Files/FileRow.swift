import SwiftUI

struct FileRow: View {
    let entry: FileEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.icon)
                .foregroundStyle(entry.isDirectory ? AppColors.accent : AppColors.muted)
                .font(.title3)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 3) {
                Text(entry.name)
                    .font(.body)
                    .foregroundStyle(AppColors.text)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if !entry.formattedSize.isEmpty {
                        Text(entry.formattedSize)
                            .font(.caption2)
                            .foregroundStyle(AppColors.muted)
                    }
                    if let modified = entry.modified {
                        Text(DateFormatters.formatRelative(from: modified))
                            .font(.caption2)
                            .foregroundStyle(AppColors.muted)
                    }
                }
            }

            Spacer()

            if entry.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppColors.muted)
            }
        }
        .padding(.vertical, 4)
    }
}
