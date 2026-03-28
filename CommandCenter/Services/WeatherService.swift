import Foundation
import CoreLocation

/// Fetches weather directly from Open-Meteo (free, no API key required).
@MainActor @Observable
final class WeatherService {
    static let shared = WeatherService()

    private(set) var current: WeatherResponse?
    private(set) var isLoading = false
    private(set) var error: String?

    private let session = URLSession.shared

    func fetch(latitude: Double, longitude: Double) async {
        isLoading = true
        error = nil

        let urlString = "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(latitude)&longitude=\(longitude)"
            + "&current=temperature_2m,relative_humidity_2m,wind_speed_10m,weather_code"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
            + "&temperature_unit=fahrenheit"
            + "&wind_speed_unit=mph"
            + "&timezone=auto"
            + "&forecast_days=6"

        guard let url = URL(string: urlString) else {
            error = "Invalid URL"
            isLoading = false
            return
        }

        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                error = "Server error"
                isLoading = false
                return
            }

            let raw = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            current = raw.toWeatherResponse(latitude: latitude, longitude: longitude)
            print("[Weather] Loaded: \(current?.current?.temp ?? -999)°F, \(current?.current?.condition ?? "?")")
        } catch {
            self.error = error.localizedDescription
            print("[Weather] Error: \(error)")
        }

        isLoading = false
    }
}

// MARK: - Open-Meteo raw response

private struct OpenMeteoResponse: Codable {
    let current: OpenMeteoCurrent?
    let daily: OpenMeteoDaily?
    let timezone: String?

    func toWeatherResponse(latitude: Double, longitude: Double) -> WeatherResponse {
        let cur: CurrentWeather? = current.map { c in
            CurrentWeather(
                temp: c.temperature_2m,
                condition: weatherCondition(from: c.weather_code),
                humidity: c.relative_humidity_2m,
                wind: c.wind_speed_10m,
                icon: weatherIcon(from: c.weather_code)
            )
        }

        var forecast: [ForecastDay] = []
        if let daily {
            let count = min(
                daily.time?.count ?? 0,
                min(daily.temperature_2m_max?.count ?? 0, daily.temperature_2m_min?.count ?? 0)
            )
            // Skip today (index 0), show next 5 days
            for i in 1..<min(count, 6) {
                let dayName = dayOfWeek(from: daily.time?[i])
                let code = (daily.weather_code?.count ?? 0) > i ? daily.weather_code?[i] : nil
                forecast.append(ForecastDay(
                    day: dayName,
                    high: daily.temperature_2m_max?[i],
                    low: daily.temperature_2m_min?[i],
                    condition: weatherCondition(from: code),
                    icon: weatherIcon(from: code)
                ))
            }
        }

        return WeatherResponse(
            current: cur,
            forecast: forecast,
            location: nil // Reverse geocoded separately
        )
    }
}

private struct OpenMeteoCurrent: Codable {
    let temperature_2m: Double?
    let relative_humidity_2m: Double?
    let wind_speed_10m: Double?
    let weather_code: Int?
}

private struct OpenMeteoDaily: Codable {
    let time: [String]?
    let weather_code: [Int]?
    let temperature_2m_max: [Double]?
    let temperature_2m_min: [Double]?
}

// MARK: - WMO Weather Code Mapping

/// Maps WMO weather interpretation codes to human-readable conditions.
/// See: https://open-meteo.com/en/docs#weathervariables
private func weatherCondition(from code: Int?) -> String {
    guard let code else { return "Unknown" }
    switch code {
    case 0: return "Clear"
    case 1: return "Mostly Clear"
    case 2: return "Partly Cloudy"
    case 3: return "Overcast"
    case 45, 48: return "Foggy"
    case 51, 53, 55: return "Drizzle"
    case 56, 57: return "Freezing Drizzle"
    case 61, 63, 65: return "Rain"
    case 66, 67: return "Freezing Rain"
    case 71, 73, 75: return "Snow"
    case 77: return "Snow Grains"
    case 80, 81, 82: return "Showers"
    case 85, 86: return "Snow Showers"
    case 95: return "Thunderstorm"
    case 96, 99: return "Thunderstorm w/ Hail"
    default: return "Unknown"
    }
}

private func weatherIcon(from code: Int?) -> String {
    guard let code else { return "cloud" }
    switch code {
    case 0: return "clear"
    case 1: return "partlycloudy"
    case 2: return "partlycloudy"
    case 3: return "cloudy"
    case 45, 48: return "cloudy"
    case 51, 53, 55, 56, 57: return "rain"
    case 61, 63, 65, 66, 67: return "rain"
    case 71, 73, 75, 77, 85, 86: return "snow"
    case 80, 81, 82: return "rain"
    case 95, 96, 99: return "storm"
    default: return "cloud"
    }
}

private func dayOfWeek(from dateString: String?) -> String {
    guard let dateString else { return "—" }
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    guard let date = formatter.date(from: dateString) else { return "—" }
    let dayFormatter = DateFormatter()
    dayFormatter.dateFormat = "EEE"
    return dayFormatter.string(from: date)
}
