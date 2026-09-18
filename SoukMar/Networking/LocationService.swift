import CoreLocation

/// One-shot "use my current location" for the listings search's GPS radius
/// filter — mirrors web's `GeocodeService.getCurrentPosition()`
/// (`navigator.geolocation.getCurrentPosition`). No server geocoding
/// involved here (that's only for a listing's own city, done backend-side);
/// this is purely the device's own GPS/network location via CoreLocation.
@MainActor
final class LocationService: NSObject, CLLocationManagerDelegate {
    static let shared = LocationService()

    enum LocationError: Error {
        case denied
        case unavailable
    }

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    private override init() {
        super.init()
        manager.delegate = self
    }

    func requestCurrentLocation() async throws -> CLLocationCoordinate2D {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            switch manager.authorizationStatus {
            case .notDetermined:
                manager.requestWhenInUseAuthorization()
            case .restricted, .denied:
                continuation.resume(throwing: LocationError.denied)
                self.continuation = nil
            default:
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                if self.continuation != nil { manager.requestLocation() }
            case .denied, .restricted:
                self.continuation?.resume(throwing: LocationError.denied)
                self.continuation = nil
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.first?.coordinate else { return }
        Task { @MainActor in
            self.continuation?.resume(returning: coordinate)
            self.continuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.continuation?.resume(throwing: error)
            self.continuation = nil
        }
    }
}
