import CoreLocation
import Observation

@MainActor
@Observable
final class LocationManager: NSObject, CLLocationManagerDelegate {
    private(set) var coordinate: CLLocationCoordinate2D?
    /// Direction of travel in degrees, when moving.
    private(set) var course: CLLocationDirection?
    /// Increments on every fix, so views can react to movement.
    private(set) var updateCount = 0
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.activityType = .fitness
    }

    func start() {
        manager.requestWhenInUseAuthorization()
        manager.startUpdatingLocation()
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        let coordinate = latest.coordinate
        let course = latest.course >= 0 ? latest.course : nil
        Task { @MainActor in
            self.coordinate = coordinate
            if let course { self.course = course }
            self.updateCount += 1
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        manager.startUpdatingLocation()
    }
}
