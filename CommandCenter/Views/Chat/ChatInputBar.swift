import SwiftUI

struct ChatInputBar: View {
    @Binding var text: String
    var onAttach: (() -> Void)?
    var onSend: () -> Void

    @FocusState private var isFocused: Bool
    @State private var sendScale: CGFloat = 1.0

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if let onAttach {
                Button(action: onAttach) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppColors.muted)
                }
                .buttonStyle(.plain)
            }

            TextField("Message Denny…", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.body)
                .foregroundStyle(AppColors.text)
                .lineLimit(1...6)
                .focused($isFocused)
                .onSubmit {
                    if canSend { doSend() }
                }

            Button(action: doSend) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(canSend ? AppColors.accent : AppColors.muted)
                    .scaleEffect(sendScale)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(AppColors.card.opacity(0.8), in: RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(AppColors.border.opacity(0.5), lineWidth: 0.5)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func doSend() {
        guard canSend else { return }
        withAnimation(.easeOut(duration: 0.1)) { sendScale = 0.7 }
        withAnimation(.spring(response: 0.3, dampingFraction: 0.5).delay(0.1)) { sendScale = 1.0 }
        onSend()
    }
}
