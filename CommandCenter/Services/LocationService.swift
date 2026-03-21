import Foundation
import CoreLocation

@MainActor @Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    var latitude: Double?
    var longitude: Double?
    var locationName: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            #if os(iOS)
            manager.requestWhenInUseAuthorization()
            #else
            manager.requestAlwaysAuthorization()
            #endif
        } else if isAuthorized(status) {
            manager.requestLocation()
        }
    }

    var queryItems: [URLQueryItem]? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return [
            URLQueryItem(name: "lat", value: String(format: "%.4f", lat)),
            URLQueryItem(name: "lon", value: String(format: "%.4f", lon))
        ]
    }

    private func isAuthorized(_ status: CLAuthorizationStatus) -> Bool {
        if status == .authorizedAlways { return true }
        #if os(iOS)
        if status == .authorizedWhenInUse { return true }
        #endif
        return false
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            self.latitude = loc.coordinate.latitude
            self.longitude = loc.coordinate.longitude
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[Location] Error: \(error.localizedDescription)")
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        let authorized = status == .authorizedAlways
        #if os(iOS)
        let whenInUse = status == .authorizedWhenInUse
        #else
        let whenInUse = false
        #endif
        if authorized || whenInUse {
            manager.requestLocation()
        }
    }
}
