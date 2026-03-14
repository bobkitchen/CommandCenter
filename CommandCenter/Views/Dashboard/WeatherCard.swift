import SwiftUI

struct WeatherCard: View {
    @State private var weather: WeatherResponse?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Weather", systemImage: "cloud.sun.fill")
                .font(.headline)
                .foregroundStyle(AppColors.accent)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if let current = weather?.current {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(weatherEmoji(current.icon))
                            .font(.system(size: 42))
                        Text(current.condition ?? "—")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.muted)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(Int(current.temp ?? 0))°")
                            .font(.system(size: 44, weight: .thin))
                            .foregroundStyle(AppColors.text)

                        HStack(spacing: 12) {
                            Label("\(Int(current.humidity ?? 0))%", systemImage: "humidity.fill")
                            Label("\(Int(current.wind ?? 0))km/h", systemImage: "wind")
                        }
                        .font(.caption)
                        .foregroundStyle(AppColors.muted)
                    }
                }

                if let forecast = weather?.forecast, !forecast.isEmpty {
                    Divider().overlay(AppColors.border)
                    HStack(spacing: 0) {
                        ForEach(forecast.prefix(5)) { day in
                            VStack(spacing: 4) {
                                Text(day.day?.prefix(3) ?? "—")
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.muted)
                                Text(weatherEmoji(day.icon))
                                    .font(.title3)
                                Text("\(Int(day.high ?? 0))°")
                                    .font(.caption)
                                    .foregroundStyle(AppColors.text)
                                Text("\(Int(day.low ?? 0))°")
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.muted)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            } else {
                Text("Unable to load weather")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.muted)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .task { await loadWeather() }
    }

    private func loadWeather() async {
        do {
            weather = try await APIClient.shared.get("/api/weather")
        } catch {}
        isLoading = false
    }

    private func weatherEmoji(_ icon: String?) -> String {
        switch icon?.lowercased() {
        case "sun", "sunny", "clear": return "☀️"
        case "cloud", "cloudy", "overcast": return "☁️"
        case "rain", "rainy": return "🌧️"
        case "storm", "thunder": return "⛈️"
        case "snow": return "❄️"
        case "partlycloudy", "partly": return "⛅"
        default: return "🌤️"
        }
    }
}
