import SwiftUI

/// Renders Markdown as styled Text views.
/// Supports: **bold**, *italic*, `code`, ```code blocks```, # headers, - lists, [links](url)
struct MarkdownText: View {
    let source: String
    @Environment(\.openURL) private var openURL

    init(_ source: String) {
        self.source = source
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }

    // MARK: - Block Parsing

    private enum Block {
        case text(String)
        case codeBlock(String, language: String?)
    }

    /// Split source into text and fenced code blocks
    private var blocks: [Block] {
        var result: [Block] = []
        var lines = source.components(separatedBy: "\n")
        var textBuffer: [String] = []
        var codeBuffer: [String] = []
        var inCode = false
        var codeLang: String?

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if inCode {
                    // End code block
                    result.append(.codeBlock(codeBuffer.joined(separator: "\n"), language: codeLang))
                    codeBuffer = []
                    inCode = false
                    codeLang = nil
                } else {
                    // Start code block — flush text buffer
                    if !textBuffer.isEmpty {
                        result.append(.text(textBuffer.joined(separator: "\n")))
                        textBuffer = []
                    }
                    inCode = true
                    let lang = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    codeLang = lang.isEmpty ? nil : lang
                }
            } else if inCode {
                codeBuffer.append(line)
            } else {
                textBuffer.append(line)
            }
        }

        // Flush remaining
        if !textBuffer.isEmpty {
            result.append(.text(textBuffer.joined(separator: "\n")))
        }
        if !codeBuffer.isEmpty {
            result.append(.codeBlock(codeBuffer.joined(separator: "\n"), language: codeLang))
        }

        return result
    }

    // MARK: - Rendering

    @ViewBuilder
    private func renderBlock(_ block: Block) -> some View {
        switch block {
        case .text(let text):
            let lines = text.components(separatedBy: "\n")
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                renderLine(line)
            }
        case .codeBlock(let code, let language):
            codeBlockView(code, language: language)
        }
    }

    private func codeBlockView(_ code: String, language: String?) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let lang = language {
                HStack {
                    Text(lang)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColors.muted)
                    Spacer()
                    Button {
                        UIPasteboard.general.string = code
                        HapticHelper.light()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.caption2)
                            .foregroundStyle(AppColors.muted)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColors.background.opacity(0.5))
            }

            Text(code)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(AppColors.text.opacity(0.9))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(AppColors.background.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(AppColors.border.opacity(0.4), lineWidth: 0.5)
        )
        .contextMenu {
            Button {
                UIPasteboard.general.string = code
                HapticHelper.light()
            } label: {
                Label("Copy Code", systemImage: "doc.on.doc")
            }
        }
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
        } else if let match = trimmed.wholeMatch(of: /^(\d+)\.\s+(.+)$/) {
            HStack(alignment: .top, spacing: 6) {
                Text("\(match.1).")
                    .foregroundStyle(AppColors.muted)
                    .font(.body)
                lineWithLinks(String(match.2))
            }
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

    /// Parse inline markdown: **bold**, *italic*, `code`
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
            } else if remaining.hasPrefix("*"),
                      let endIdx = remaining[remaining.index(after: remaining.startIndex)...].firstIndex(of: "*") {
                let content = remaining[remaining.index(after: remaining.startIndex)..<endIdx]
                result = result + Text(content).italic()
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
                if linkStart > remaining.startIndex {
                    segments.append(TextSegment(text: String(remaining[remaining.startIndex..<linkStart]), url: nil))
                }
                if let closeBracket = remaining[remaining.index(after: linkStart)...].firstIndex(of: "]"),
                   remaining[remaining.index(after: closeBracket)...].hasPrefix("("),
                   let closeParen = remaining[remaining.index(closeBracket, offsetBy: 2)...].firstIndex(of: ")") {
                    let linkText = String(remaining[remaining.index(after: linkStart)..<closeBracket])
                    let urlString = String(remaining[remaining.index(closeBracket, offsetBy: 2)..<closeParen])
                    let url = URL(string: urlString)
                    segments.append(TextSegment(text: linkText, url: url))
                    remaining = remaining[remaining.index(after: closeParen)...]
                } else {
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
