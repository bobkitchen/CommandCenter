import SwiftUI

struct ChatSearchBar: View {
    @Binding var searchText: String
    let resultCount: Int
    let currentIndex: Int
    var onPrevious: () -> Void
    var onNext: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.caption)
                .foregroundStyle(AppColors.muted)

            TextField("Search messages…", text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(AppColors.text)

            if !searchText.isEmpty {
                Text(resultCount > 0 ? "\(currentIndex + 1)/\(resultCount)" : "0")
                    .font(.caption2)
                    .foregroundStyle(AppColors.muted)
                    .monospacedDigit()

                Button(action: onPrevious) {
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(resultCount > 0 ? AppColors.text : AppColors.muted)
                }
                .disabled(resultCount == 0)
                .buttonStyle(.plain)

                Button(action: onNext) {
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(resultCount > 0 ? AppColors.text : AppColors.muted)
                }
                .disabled(resultCount == 0)
                .buttonStyle(.plain)
            }

            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppColors.muted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.card.opacity(0.95), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppColors.border.opacity(0.5), lineWidth: 0.5)
        )
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }
}
