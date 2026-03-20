import WidgetKit
import SwiftUI

// MARK: - Shared Data (duplicated from main app since widget is a separate target)

struct WidgetData: Codable {
    let isConnected: Bool
    let contextPercent: Double
    let healthSummary: String
    let model: String
    let uptime: String
    let agentCount: Int
    let lastUpdated: Date

    static let placeholder = WidgetData(
        isConnected: true,
        contextPercent: 42,
        healthSummary: "All Systems Operational",
        model: "sonnet-4",
        uptime: "2d 5h",
        agentCount: 3,
        lastUpdated: Date()
    )

    static func load() -> WidgetData {
        guard let defaults = UserDefaults(suiteName: "group.com.bobkitchen.commandcenter"),
              let data = defaults.data(forKey: "widgetData"),
              let decoded = try? JSONDecoder().decode(WidgetData.self, from: data) else {
            return .placeholder
        }
        return decoded
    }
}

// MARK: - Timeline Provider

struct CommandCenterProvider: TimelineProvider {
    func placeholder(in context: Context) -> CommandCenterEntry {
        CommandCenterEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CommandCenterEntry) -> Void) {
        completion(CommandCenterEntry(date: Date(), data: WidgetData.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CommandCenterEntry>) -> Void) {
        let entry = CommandCenterEntry(date: Date(), data: WidgetData.load())
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 5, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct CommandCenterEntry: TimelineEntry {
    let date: Date
    let data: WidgetData
}

// MARK: - Widget Views

struct CommandCenterWidgetEntryView: View {
    var entry: CommandCenterEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(entry.data.isConnected ? Color.green : Color.red)
                    .frame(width: 10, height: 10)

                Text("OpenClaw")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.primary)
            }

            Spacer()

            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(entry.data.contextPercent / 100, 1))
                    .stroke(contextColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(entry.data.contextPercent))")
                        .font(.title2.weight(.bold))
                    Text("%")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 70, height: 70)
            .frame(maxWidth: .infinity)

            Spacer()

            Text(entry.data.healthSummary)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(12)
        .containerBackground(for: .widget) {
            Color.black
        }
    }

    private var mediumWidget: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Circle()
                        .fill(entry.data.isConnected ? Color.green : Color.red)
                        .frame(width: 10, height: 10)

                    Text("OpenClaw")
                        .font(.subheadline.weight(.bold))
                }

                Text(entry.data.healthSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    statRow("Model", value: entry.data.model)
                    statRow("Uptime", value: entry.data.uptime)
                    statRow("Agents", value: "\(entry.data.agentCount)")
                }
            }

            VStack {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    Circle()
                        .trim(from: 0, to: min(entry.data.contextPercent / 100, 1))
                        .stroke(contextColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(Int(entry.data.contextPercent))")
                            .font(.title.weight(.bold))
                        Text("context")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 80, height: 80)

                Text(timeAgo)
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .containerBackground(for: .widget) {
            Color.black
        }
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 10, weight: .medium))
        }
    }

    private var contextColor: Color {
        if entry.data.contextPercent > 80 { return .red }
        if entry.data.contextPercent > 50 { return .orange }
        return .green
    }

    private var timeAgo: String {
        let seconds = Int(Date().timeIntervalSince(entry.data.lastUpdated))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        return "\(seconds / 3600)h ago"
    }
}

// MARK: - Widget Definition

struct CommandCenterWidget: Widget {
    let kind: String = "CommandCenterWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CommandCenterProvider()) { entry in
            CommandCenterWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Command Center")
        .description("Monitor OpenClaw system health at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
