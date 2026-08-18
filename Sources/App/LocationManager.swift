import CoreLocation
import Observation

@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var pendingContinuations: [CheckedContinuation<CLLocationCoordinate2D?, Never>] = []
    private var authContinuation: CheckedContinuation<CLAuthorizationStatus, Never>?

    private(set) var latitude: Double?
    private(set) var longitude: Double?
    private(set) var authorizationDenied = false

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestWhenInUse() {
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
    }

    /// One-shot location fix. Returns coordinates if authorized, nil otherwise.
    func requestLocation(forceFresh: Bool = false) async -> CLLocationCoordinate2D? {
        var status = manager.authorizationStatus
        if status == .notDetermined {
            status = await withCheckedContinuation { continuation in
                authContinuation = continuation
                manager.requestWhenInUseAuthorization()
            }
        }

        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            authorizationDenied = (status == .denied || status == .restricted)
            return nil
        }
        authorizationDenied = false

        if !forceFresh, let latitude, let longitude {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        return await withCheckedContinuation { continuation in
            pendingContinuations.append(continuation)
            manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let coordinate = locations.first?.coordinate
        Task { @MainActor in
            if let coordinate {
                latitude = coordinate.latitude
                longitude = coordinate.longitude
                authorizationDenied = false
            }
            let continuations = pendingContinuations
            pendingContinuations.removeAll()
            for continuation in continuations {
                continuation.resume(returning: coordinate)
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let clErr = error as? CLError, clErr.code == .denied {
                authorizationDenied = true
            }
            let continuations = pendingContinuations
            pendingContinuations.removeAll()
            let fallback = latitude.flatMap { lat in longitude.map { lon in CLLocationCoordinate2D(latitude: lat, longitude: lon) } }
            for continuation in continuations {
                continuation.resume(returning: fallback)
            }
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            authorizationDenied = (status == .denied || status == .restricted)
            if let auth = authContinuation {
                authContinuation = nil
                auth.resume(returning: status)
            }
        }
    }
}
