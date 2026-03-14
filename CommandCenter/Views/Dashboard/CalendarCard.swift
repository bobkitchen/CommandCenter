import SwiftUI

struct CalendarCard: View {
    @State private var events: [CalendarEvent] = []
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Calendar", systemImage: "calendar")
                .font(.headline)
                .foregroundStyle(AppColors.accent)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if events.isEmpty {
                Text("No upcoming events")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.muted)
            } else {
                VStack(spacing: 8) {
                    ForEach(events.prefix(5)) { event in
                        HStack(alignment: .top, spacing: 10) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(calendarColor(event.calendar))
                                .frame(width: 4, height: 36)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.text)
                                    .lineLimit(1)

                                HStack(spacing: 6) {
                                    Text(event.startTime)
                                        .font(.caption)
                                        .foregroundStyle(AppColors.muted)

                                    if let loc = event.location, !loc.isEmpty {
                                        Text("· \(loc)")
                                            .font(.caption)
                                            .foregroundStyle(AppColors.muted)
                                            .lineLimit(1)
                                    }
                                }
                            }

                            Spacer()
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .task { await loadEvents() }
    }

    private func loadEvents() async {
        do {
            let response: CalendarResponse = try await APIClient.shared.get("/api/calendar")
            events = response.events
        } catch {}
        isLoading = false
    }

    private func calendarColor(_ name: String?) -> Color {
        switch name?.lowercased() {
        case "outlook": return .blue
        case "appointments": return .orange
        case "iftt", "ifttt": return .green
        default: return AppColors.accent
        }
    }
}
