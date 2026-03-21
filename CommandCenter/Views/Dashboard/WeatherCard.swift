import SwiftUI

struct WeatherCard: View {
    @State private var weather: WeatherResponse?
    @State private var isLoading = true
    @State private var loadError = false
    @State private var errorDetail: String?
    @State private var location = LocationService.shared
    @State private var hasFetchedWithLocation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Weather", systemImage: "cloud.sun.fill")
                    .font(.headline)
                    .foregroundStyle(AppColors.accent)

                Spacer()

                if let name = weather?.location {
                    Text(name)
                        .font(.caption2)
                        .foregroundStyle(AppColors.muted)
                }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else if loadError {
                ErrorRetryView(message: errorDetail ?? "Unable to load weather") {
                    Task { await loadWeather() }
                }
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
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard()
        .task {
            location.requestLocation()
            await loadWeather()
        }
        .onChange(of: location.latitude) {
            guard !hasFetchedWithLocation, location.latitude != nil else { return }
            hasFetchedWithLocation = true
            Task { await loadWeather() }
        }
    }

    private func loadWeather() async {
        isLoading = true
        loadError = false
        errorDetail = nil
        do {
            let coords = location.queryItems
            print("[Weather] Loading with coords: \(coords?.map { "\($0.name)=\($0.value ?? "")" } ?? ["none"])")
            weather = try await APIClient.shared.get("/api/weather", queryItems: coords)
            print("[Weather] Loaded OK – location: \(weather?.location ?? "nil"), temp: \(weather?.current?.temp ?? -999)")
        } catch let apiError as APIError {
            loadError = true
            errorDetail = apiError.errorDescription
            print("[Weather] API error: \(apiError.errorDescription ?? "unknown")")
        } catch let decodingError as DecodingError {
            loadError = true
            switch decodingError {
            case .keyNotFound(let key, _):
                errorDetail = "Missing field: \(key.stringValue)"
            case .typeMismatch(let type, let ctx):
                errorDetail = "Type mismatch at \(ctx.codingPath.map(\.stringValue).joined(separator: ".")): expected \(type)"
            default:
                errorDetail = "Decoding error"
            }
            print("[Weather] Decode error: \(decodingError)")
        } catch {
            loadError = true
            errorDetail = error.localizedDescription
            print("[Weather] Error: \(error)")
        }
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
