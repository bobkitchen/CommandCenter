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
                        Text(formatDate(modified))
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

    private func formatDate(_ str: String) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()

        let date: Date?
        if let d = isoFormatter.date(from: str) {
            date = d
        } else if let d = isoBasic.date(from: str) {
            date = d
        } else {
            date = nil
        }

        guard let date else { return str }
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}
