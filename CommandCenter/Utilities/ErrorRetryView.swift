import SwiftUI

struct ErrorRetryView: View {
    let message: String
    var onRetry: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.title2)
                .foregroundStyle(AppColors.warning)
            Text(message)
                .font(.caption)
                .foregroundStyle(AppColors.muted)
                .multilineTextAlignment(.center)
            if let onRetry {
                Button {
                    HapticHelper.light()
                    onRetry()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.accent)
                }
            }
        }
    }
}
