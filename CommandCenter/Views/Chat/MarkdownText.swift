import SwiftUI

/// Renders basic Markdown as styled Text views.
/// Supports: **bold**, `code`, # headers, - lists, [links](url) (tappable)
struct MarkdownText: View {
    let source: String
    @Environment(\.openURL) private var openURL

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
                lineWithLinks(String(trimmed.dropFirst(2)))
            }
        } else if trimmed.hasPrefix("```") {
            Text(trimmed)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(AppColors.muted)
        } else {
            lineWithLinks(trimmed)
        }
    }

    /// Renders a line that may contain tappable links as an HStack
    @ViewBuilder
    private func lineWithLinks(_ text: String) -> some View {
        let segments = parseSegments(text)
        let hasLinks = segments.contains { $0.url != nil }

        if hasLinks {
            // Use a flow layout with tappable link buttons
            HStack(spacing: 0) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    if let url = segment.url {
                        Button {
                            openURL(url)
                        } label: {
                            Text(segment.text)
                                .foregroundStyle(AppColors.accent)
                                .underline()
                        }
                    } else {
                        styledInline(segment.text)
                            .foregroundStyle(AppColors.text)
                    }
                }
            }
        } else {
            styledInline(text)
                .foregroundStyle(AppColors.text)
        }
    }

    /// Parse inline markdown: **bold**, `code`
    private func styledInline(_ text: String) -> Text {
        var result = Text("")
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            if remaining.hasPrefix("**"),
               let endRange = remaining[remaining.index(remaining.startIndex, offsetBy: 2)...].range(of: "**") {
                let content = remaining[remaining.index(remaining.startIndex, offsetBy: 2)..<endRange.lowerBound]
                result = result + Text(content).bold()
                remaining = remaining[endRange.upperBound...]
            } else if remaining.hasPrefix("`"),
                      let endIdx = remaining[remaining.index(after: remaining.startIndex)...].firstIndex(of: "`") {
                let content = remaining[remaining.index(after: remaining.startIndex)..<endIdx]
                result = result + Text(content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(AppColors.accent)
                remaining = remaining[remaining.index(after: endIdx)...]
            } else {
                let char = remaining[remaining.startIndex]
                result = result + Text(String(char))
                remaining = remaining[remaining.index(after: remaining.startIndex)...]
            }
        }

        return result
    }

    // MARK: - Link parsing

    private struct TextSegment {
        let text: String
        let url: URL?
    }

    /// Split text into segments of plain text and [link](url) pairs
    private func parseSegments(_ text: String) -> [TextSegment] {
        var segments: [TextSegment] = []
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            if let linkStart = remaining.firstIndex(of: "[") {
                // Add text before the link
                if linkStart > remaining.startIndex {
                    segments.append(TextSegment(text: String(remaining[remaining.startIndex..<linkStart]), url: nil))
                }
                // Try to parse [text](url)
                if let closeBracket = remaining[remaining.index(after: linkStart)...].firstIndex(of: "]"),
                   remaining[remaining.index(after: closeBracket)...].hasPrefix("("),
                   let closeParen = remaining[remaining.index(closeBracket, offsetBy: 2)...].firstIndex(of: ")") {
                    let linkText = String(remaining[remaining.index(after: linkStart)..<closeBracket])
                    let urlString = String(remaining[remaining.index(closeBracket, offsetBy: 2)..<closeParen])
                    let url = URL(string: urlString)
                    segments.append(TextSegment(text: linkText, url: url))
                    remaining = remaining[remaining.index(after: closeParen)...]
                } else {
                    // Not a valid link, treat [ as plain text
                    segments.append(TextSegment(text: String(remaining[linkStart...linkStart]), url: nil))
                    remaining = remaining[remaining.index(after: linkStart)...]
                }
            } else {
                segments.append(TextSegment(text: String(remaining), url: nil))
                break
            }
        }

        return segments
    }
}
