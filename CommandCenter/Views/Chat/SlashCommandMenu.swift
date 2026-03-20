import SwiftUI

struct SlashCommand: Identifiable {
    let id = UUID()
    let command: String
    let icon: String
    let label: String
    let prompt: String

    static let all: [SlashCommand] = [
        SlashCommand(command: "/weather", icon: "cloud.sun", label: "Weather", prompt: "What's the weather like right now?"),
        SlashCommand(command: "/calendar", icon: "calendar", label: "Today's Schedule", prompt: "What's on my calendar today?"),
        SlashCommand(command: "/status", icon: "server.rack", label: "System Status", prompt: "Give me a quick system status update."),
        SlashCommand(command: "/crises", icon: "exclamationmark.triangle", label: "Crisis Update", prompt: "Any active crises or alerts I should know about?"),
        SlashCommand(command: "/summary", icon: "doc.text", label: "Daily Summary", prompt: "Give me a summary of today — weather, calendar, any alerts, and system status."),
        SlashCommand(command: "/strava", icon: "bicycle", label: "Fitness Stats", prompt: "What are my latest Strava stats?"),
        SlashCommand(command: "/memory", icon: "brain", label: "What You Remember", prompt: "What do you currently remember about me?"),
        SlashCommand(command: "/help", icon: "questionmark.circle", label: "What Can You Do?", prompt: "What can you help me with? Give me a quick overview of your capabilities."),
    ]

    /// Filter commands matching partial input (e.g. "/wea" matches "/weather")
    static func matching(_ input: String) -> [SlashCommand] {
        let lower = input.lowercased()
        if lower == "/" { return all }
        return all.filter { $0.command.hasPrefix(lower) }
    }
}

struct SlashCommandMenu: View {
    let commands: [SlashCommand]
    let onSelect: (SlashCommand) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(commands) { cmd in
                Button {
                    HapticHelper.light()
                    onSelect(cmd)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: cmd.icon)
                            .font(.body)
                            .foregroundStyle(AppColors.accent)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(cmd.command)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(AppColors.text)
                            Text(cmd.label)
                                .font(.caption)
                                .foregroundStyle(AppColors.muted)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if cmd.id != commands.last?.id {
                    Divider()
                        .background(AppColors.border.opacity(0.3))
                }
            }
        }
        .background(AppColors.card.opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.border.opacity(0.5), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.3), radius: 12, y: -4)
        .padding(.horizontal, 12)
    }
}
