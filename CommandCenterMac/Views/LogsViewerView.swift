import SwiftUI

#if os(macOS)
struct LogsViewerView: View {
    @State private var logsService = LogsService()
    @State private var searchText = ""
    @State private var autoScroll = true

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack(spacing: 8) {
                Picker("Source", selection: $logsService.source) {
                    ForEach(LogsService.LogSource.allCases, id: \.self) { src in
                        Text(src.rawValue.capitalized).tag(src)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)

                TextField("Filter logs...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 300)

                Spacer()

                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.switch)
                    .controlSize(.small)

                Button {
                    logsService.clearLogs()
                } label: {
                    Image(systemName: "trash")
                }
                .help("Clear log lines")

                // Connection status indicator
                Circle()
                    .fill(logsService.isConnected ? AppColors.success : AppColors.danger)
                    .frame(width: 8, height: 8)
                    .help(logsService.isConnected ? "WebSocket connected" : "WebSocket disconnected")
            }
            .padding(8)
            .background(AppColors.card)

            Divider()

            // Log area
            if logsService.isLoading && logsService.lines.isEmpty {
                Spacer()
                ProgressView("Loading logs…")
                    .foregroundStyle(AppColors.muted)
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 1) {
                            ForEach(filteredLines) { line in
                                logLineView(line)
                                    .id(line.id)
                            }
                        }
                        .padding(8)
                    }
                    .onChange(of: logsService.lines.count) {
                        if autoScroll, let last = filteredLines.last {
                            withAnimation(.none) {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
                .background(Color.black)
                .font(.system(.caption, design: .monospaced))
            }

            if let error = logsService.error {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text(error)
                }
                .foregroundStyle(AppColors.danger)
                .font(.caption)
                .padding(6)
                .background(AppColors.card)
            }
        }
        .task {
            await logsService.loadInitialLogs()
            logsService.connectWebSocket()
        }
        .onDisappear {
            logsService.disconnect()
        }
        .onChange(of: logsService.source) {
            logsService.clearLogs()
            Task {
                await logsService.loadInitialLogs()
                logsService.disconnect()
                logsService.connectWebSocket()
            }
        }
    }

    // MARK: - Computed

    private var filteredLines: [LogsService.LogLine] {
        guard !searchText.isEmpty else { return logsService.lines }
        return logsService.lines.filter {
            $0.message.localizedCaseInsensitiveContains(searchText) ||
            $0.source.localizedCaseInsensitiveContains(searchText) ||
            $0.level.localizedCaseInsensitiveContains(searchText)
        }
    }

    // MARK: - Log Line Row

    private func logLineView(_ line: LogsService.LogLine) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(formattedTimestamp(line.timestamp))
                .foregroundStyle(.secondary)
                .frame(width: 85, alignment: .leading)
                .lineLimit(1)

            Text(line.level.uppercased())
                .foregroundStyle(levelColor(line.level))
                .frame(width: 48, alignment: .leading)
                .lineLimit(1)

            Text(line.source)
                .foregroundStyle(AppColors.accent)
                .frame(width: 68, alignment: .leading)
                .lineLimit(1)

            Text(line.message)
                .foregroundStyle(AppColors.text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 1)
    }

    // MARK: - Helpers

    private func levelColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "error":           return AppColors.danger
        case "warn", "warning": return AppColors.warning
        case "info":            return AppColors.accent
        default:                return AppColors.muted
        }
    }

    /// Shorten ISO8601 timestamps to HH:mm:ss for compact display.
    private func formattedTimestamp(_ raw: String) -> String {
        // Try to extract just the time portion from ISO8601 (e.g. "2026-03-20T14:30:00Z")
        if raw.count >= 19, raw.contains("T") {
            let start = raw.index(raw.startIndex, offsetBy: 11)
            let end = raw.index(raw.startIndex, offsetBy: 19)
            return String(raw[start..<end])
        }
        // Fallback: return as-is, truncated to 12 chars
        return String(raw.prefix(12))
    }
}
#endif
