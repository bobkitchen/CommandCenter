import Foundation

struct WeatherResponse: Codable {
    let current: CurrentWeather?
    let forecast: [ForecastDay]?
    let location: String?
}

struct CurrentWeather: Codable {
    let temp: Double?
    let condition: String?
    let humidity: Double?
    let wind: Double?
    let icon: String?
}

struct ForecastDay: Codable, Identifiable {
    let day: String?
    let high: Double?
    let low: Double?
    let condition: String?
    let icon: String?

    var id: String { day ?? UUID().uuidString }
}
