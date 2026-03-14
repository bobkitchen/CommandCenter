import SwiftUI

/// Renders basic Markdown as styled Text views.
/// Supports: **bold**, `code`, # headers, - lists, [links](url)
struct MarkdownText: View {
    let source: String

    init(_ source: String) {
        self.source = source
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                renderLine(line)
            }
        }
    }

    private var lines: [String] {
        source.components(separatedBy: "\n")
    }

    @ViewBuilder
    private func renderLine(_ line: String) -> some View {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            Spacer().frame(height: 4)
        } else if trimmed.hasPrefix("### ") {
            styledInline(String(trimmed.dropFirst(4)))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.text)
        } else if trimmed.hasPrefix("## ") {
            styledInline(String(trimmed.dropFirst(3)))
                .font(.headline)
                .foregroundStyle(AppColors.text)
        } else if trimmed.hasPrefix("# ") {
            styledInline(String(trimmed.dropFirst(2)))
                .font(.title3.weight(.bold))
                .foregroundStyle(AppColors.text)
        } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .foregroundStyle(AppColors.muted)
                styledInline(String(trimmed.dropFirst(2)))
                    .foregroundStyle(AppColors.text)
            }
        } else if trimmed.hasPrefix("```") {
            // Simple code block marker — just show as-is in monospace
            Text(trimmed)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(AppColors.muted)
        } else {
            styledInline(trimmed)
                .foregroundStyle(AppColors.text)
        }
    }

    /// Parse inline markdown: **bold**, `code`, [links](url)
    private func styledInline(_ text: String) -> Text {
        var result = Text("")
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            // Bold: **text**
            if remaining.hasPrefix("**"),
               let endRange = remaining[remaining.index(remaining.startIndex, offsetBy: 2)...].range(of: "**") {
                let content = remaining[remaining.index(remaining.startIndex, offsetBy: 2)..<endRange.lowerBound]
                result = result + Text(content).bold()
                remaining = remaining[endRange.upperBound...]
            }
            // Inline code: `text`
            else if remaining.hasPrefix("`"),
                    let endIdx = remaining[remaining.index(after: remaining.startIndex)...].firstIndex(of: "`") {
                let content = remaining[remaining.index(after: remaining.startIndex)..<endIdx]
                result = result + Text(content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(AppColors.accent)
                remaining = remaining[remaining.index(after: endIdx)...]
            }
            // Link: [text](url) — render as text in accent color
            else if remaining.hasPrefix("["),
                    let closeBracket = remaining.firstIndex(of: "]"),
                    remaining[remaining.index(after: closeBracket)...].hasPrefix("("),
                    let closeParen = remaining[remaining.index(closeBracket, offsetBy: 2)...].firstIndex(of: ")") {
                let linkText = remaining[remaining.index(after: remaining.startIndex)..<closeBracket]
                result = result + Text(linkText)
                    .foregroundColor(AppColors.accent)
                    .underline()
                remaining = remaining[remaining.index(after: closeParen)...]
            }
            // Plain character
            else {
                let char = remaining[remaining.startIndex]
                result = result + Text(String(char))
                remaining = remaining[remaining.index(after: remaining.startIndex)...]
            }
        }

        return result
    }
}
