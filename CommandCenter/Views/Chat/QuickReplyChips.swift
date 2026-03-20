import SwiftUI

struct QuickReplyChips: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions, id: \.self) { text in
                    Button {
                        HapticHelper.light()
                        onSelect(text)
                    } label: {
                        Text(text)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppColors.card, in: Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(AppColors.accent.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
        }
        .frame(height: 40)
    }

    /// Generate contextual quick reply suggestions based on the last assistant message
    static func suggestions(for lastMessage: Message?) -> [String] {
        guard let msg = lastMessage, !msg.isUser else { return [] }
        let text = msg.cleanedContent.lowercased()

        // Question detection
        let isQuestion = text.hasSuffix("?") || text.contains("would you") || text.contains("do you want")
            || text.contains("shall i") || text.contains("should i") || text.contains("let me know")

        // Yes/no questions
        if isQuestion && (text.contains("would you like") || text.contains("do you want")
            || text.contains("shall i") || text.contains("should i") || text.contains("want me to")) {
            return ["Yes, go ahead", "No thanks", "Tell me more"]
        }

        // "Anything else" pattern
        if text.contains("anything else") || text.contains("something else") || text.contains("help with") {
            return ["That's all, thanks", "Yes, one more thing", "/summary"]
        }

        // Greeting
        if text.contains("good morning") || text.contains("good afternoon") || text.contains("good evening")
            || text.contains("hello") || text.contains("hey there") || text.contains("hi bob") {
            return ["/summary", "/calendar", "/weather"]
        }

        // Status/report
        if text.contains("status") || text.contains("running") || text.contains("system") || text.contains("uptime") {
            return ["Thanks", "Any issues?", "Restart anything?"]
        }

        // Weather
        if text.contains("weather") || text.contains("temperature") || text.contains("forecast") {
            return ["Thanks", "/calendar", "What about tomorrow?"]
        }

        // Calendar
        if text.contains("calendar") || text.contains("schedule") || text.contains("meeting") || text.contains("event") {
            return ["Thanks", "Reschedule anything?", "/weather"]
        }

        // Crisis/alert
        if text.contains("crisis") || text.contains("alert") || text.contains("critical") {
            return ["Tell me more", "What should I do?", "Keep monitoring"]
        }

        // Generic question
        if isQuestion {
            return ["Yes", "No", "Tell me more"]
        }

        // Default — offer common actions
        if text.count > 50 {
            return ["Thanks", "Got it", "/summary"]
        }

        return []
    }
}
