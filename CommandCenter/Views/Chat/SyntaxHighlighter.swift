import SwiftUI

struct SyntaxHighlightedCode: View {
    let code: String
    let language: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(code.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                highlightedLine(line)
            }
        }
    }

    private func highlightedLine(_ line: String) -> some View {
        let tokens = tokenize(line)
        return HStack(spacing: 0) {
            ForEach(Array(tokens.enumerated()), id: \.offset) { _, token in
                Text(token.text)
                    .foregroundStyle(token.color)
            }
            Spacer(minLength: 0)
        }
        .font(.system(.caption, design: .monospaced))
    }

    // MARK: - Token

    struct Token {
        let text: String
        let color: Color
    }

    // MARK: - Tokenizer

    private func tokenize(_ line: String) -> [Token] {
        let lang = language?.lowercased() ?? ""
        var tokens: [Token] = []
        var remaining = line[line.startIndex...]

        while !remaining.isEmpty {
            // Comments
            if remaining.hasPrefix("//") || (isHashComment(lang) && remaining.hasPrefix("#") && !remaining.hasPrefix("#!")) {
                tokens.append(Token(text: String(remaining), color: SyntaxColors.comment))
                return tokens
            }

            // Strings
            if let q = remaining.first, q == "\"" || q == "'" {
                if let end = findClosingQuote(remaining, quote: q) {
                    tokens.append(Token(text: String(remaining[remaining.startIndex...end]), color: SyntaxColors.string))
                    remaining = remaining[remaining.index(after: end)...]
                    continue
                }
            }

            // Numbers
            if let d = remaining.first, d.isNumber {
                var end = remaining.startIndex
                while end < remaining.endIndex && (remaining[end].isNumber || remaining[end] == "." || remaining[end] == "x") {
                    end = remaining.index(after: end)
                }
                tokens.append(Token(text: String(remaining[remaining.startIndex..<end]), color: SyntaxColors.number))
                remaining = remaining[end...]
                continue
            }

            // Words
            if let first = remaining.first, first.isLetter || first == "_" || first == "@" || first == "$" {
                var end = remaining.startIndex
                while end < remaining.endIndex && (remaining[end].isLetter || remaining[end].isNumber || remaining[end] == "_") {
                    end = remaining.index(after: end)
                }
                let word = String(remaining[remaining.startIndex..<end])
                tokens.append(Token(text: word, color: colorForWord(word)))
                remaining = remaining[end...]
                continue
            }

            // Punctuation
            let char = String(remaining.first!)
            let color: Color = "{}()[]<>".contains(char) ? SyntaxColors.bracket : SyntaxColors.plain
            tokens.append(Token(text: char, color: color))
            remaining = remaining[remaining.index(after: remaining.startIndex)...]
        }

        return tokens.isEmpty ? [Token(text: line, color: SyntaxColors.plain)] : tokens
    }

    private func findClosingQuote(_ str: Substring, quote: Character) -> String.Index? {
        guard str.count > 1 else { return nil }
        var i = str.index(after: str.startIndex)
        while i < str.endIndex {
            if str[i] == quote && str[str.index(before: i)] != "\\" { return i }
            i = str.index(after: i)
        }
        return nil
    }

    private func isHashComment(_ lang: String) -> Bool {
        ["python", "py", "ruby", "rb", "shell", "bash", "sh", "zsh", "yaml", "yml"].contains(lang)
    }

    private func colorForWord(_ word: String) -> Color {
        if word.hasPrefix("@") { return SyntaxColors.decorator }
        if word.hasPrefix("$") { return SyntaxColors.variable }

        if Self.keywords.contains(word) { return SyntaxColors.keyword }
        if Self.types.contains(word) { return SyntaxColors.type }
        if let first = word.first, first.isUppercase && word.count > 1 { return SyntaxColors.type }

        return SyntaxColors.plain
    }

    private static let keywords: Set<String> = [
        "if", "else", "for", "while", "return", "switch", "case", "break",
        "continue", "default", "do", "try", "catch", "throw", "throws",
        "import", "from", "as", "in", "is", "new", "delete", "typeof",
        "true", "false", "nil", "null", "undefined", "None", "True", "False",
        "class", "struct", "enum", "protocol", "interface", "trait",
        "func", "function", "fn", "def", "var", "let", "const", "val",
        "static", "final", "override", "private", "public", "internal",
        "protected", "open", "fileprivate", "export", "module",
        "async", "await", "yield", "defer", "guard", "where",
        "self", "Self", "super", "this", "init", "deinit",
        "type", "typealias", "extension", "impl",
        "some", "any", "mut", "ref", "pub", "use", "mod", "crate",
        "package", "require", "include",
    ]

    private static let types: Set<String> = [
        "String", "Int", "Double", "Float", "Bool", "Array", "Dictionary",
        "Set", "Optional", "Result", "Error", "Void", "Any", "AnyObject",
        "Task", "View", "Body", "Scene", "App",
        "Promise", "Observable", "State", "Binding", "Published",
        "List", "Map", "HashMap", "Vec", "Option",
    ]
}

// MARK: - Syntax Colors

enum SyntaxColors {
    static let keyword = Color(red: 0.78, green: 0.47, blue: 0.86)
    static let string = Color(red: 0.58, green: 0.79, blue: 0.49)
    static let comment = Color(red: 0.45, green: 0.50, blue: 0.55)
    static let number = Color(red: 0.71, green: 0.84, blue: 0.99)
    static let type = Color(red: 0.90, green: 0.76, blue: 0.47)
    static let decorator = Color(red: 0.90, green: 0.76, blue: 0.47)
    static let variable = Color(red: 0.56, green: 0.76, blue: 0.97)
    static let bracket = Color(red: 0.85, green: 0.85, blue: 0.85)
    static let plain = Color(red: 0.84, green: 0.86, blue: 0.88)
}
