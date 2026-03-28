import SwiftUI
import CoreLocation

struct WeatherCard: View {
    @State private var weather = WeatherService.shared
    @State private var location = LocationService.shared
    @State private var locationName: String?
    @State private var hasFetched = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Weather", systemImage: "cloud.sun.fill")
                    .font(.headline)
                    .foregroundStyle(AppColors.accent)

                Spacer()

                if let name = locationName {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(AppColors.muted)
                }
            }

            if weather.isLoading && weather.current == nil {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if let error = weather.error, weather.current == nil {
                ErrorRetryView(message: error) {
                    Task { await fetchWeather() }
                }
                .frame(maxWidth: .infinity, minHeight: 60)
            } else if let current = weather.current?.current {
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
                            Label("\(Int(current.wind ?? 0)) mph", systemImage: "wind")
                        }
                        .font(.caption)
                        .foregroundStyle(AppColors.muted)
                    }
                }

                if let forecast = weather.current?.forecast, !forecast.isEmpty {
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
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .task {
            location.requestLocation()
            // If we already have location, fetch immediately
            if location.latitude != nil {
                await fetchWeather()
            }
        }
        .onChange(of: location.latitude) {
            guard !hasFetched, location.latitude != nil else { return }
            Task { await fetchWeather() }
        }
    }

    private func fetchWeather() async {
        guard let lat = location.latitude, let lon = location.longitude else {
            // Fallback to Boise if no location available
            hasFetched = true
            await weather.fetch(latitude: 43.6150, longitude: -116.2023)
            await reverseGeocode(latitude: 43.6150, longitude: -116.2023)
            return
        }
        hasFetched = true
        await weather.fetch(latitude: lat, longitude: lon)
        await reverseGeocode(latitude: lat, longitude: lon)
    }

    private func reverseGeocode(latitude: Double, longitude: Double) async {
        let geocoder = CLGeocoder()
        let loc = CLLocation(latitude: latitude, longitude: longitude)
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(loc)
            if let place = placemarks.first {
                locationName = [place.locality, place.administrativeArea]
                    .compactMap { $0 }
                    .joined(separator: ", ")
            }
        } catch {
            print("[Weather] Geocode error: \(error.localizedDescription)")
        }
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
