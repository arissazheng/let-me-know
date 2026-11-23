import CoreLocation
import Foundation
import Observation
import Supabase

/// Student population density from preference-based location tracking (blue glow).
@MainActor
@Observable
final class PopulationStore {
    struct Cell: Decodable {
        let lat: Double
        let lng: Double
        let weight: Int

        var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }
    }

    private(set) var cells: [Cell] = []
    private var maxWeight = 1

    /// Refreshes the aggregate every 30 seconds while the map is open.
    func keepFresh() async {
        while !Task.isCancelled {
            await load()
            try? await Task.sleep(for: .seconds(30))
        }
    }

    func load() async {
        guard let response = try? await supabase.rpc("population_cells").execute(),
              let cells = try? JSONDecoder().decode([Cell].self, from: response.data)
        else { return }
        self.cells = cells
        maxWeight = max(cells.map(\.weight).max() ?? 1, 1)
    }

    /// 0 (empty) … 1 (busiest cell on the map), averaged over nearby cells.
    func crowdLevel(near point: CLLocationCoordinate2D, radius: CLLocationDistance = 40) -> Double {
        let here = CLLocation(latitude: point.latitude, longitude: point.longitude)
        let nearby = cells.filter { here.distance(from: CLLocation(latitude: $0.lat, longitude: $0.lng)) <= radius }
        let total = nearby.reduce(0) { $0 + $1.weight }
        return min(Double(total) / Double(maxWeight * 3), 1)
    }

    /// While sharing is on, sends an anonymous ping (rounded to ~11 m) whenever the student has
    /// moved 25 m, or at least once a minute, so the density map tracks where people are now.
    func sharePings(from location: LocationManager) async {
        var lastSent: (coordinate: CLLocation, at: Date)?
        while !Task.isCancelled {
            if let c = location.coordinate {
                let here = CLLocation(latitude: c.latitude, longitude: c.longitude)
                let moved = lastSent.map { here.distance(from: $0.coordinate) >= 25 } ?? true
                let stale = lastSent.map { Date().timeIntervalSince($0.at) >= 60 } ?? true
                if moved || stale {
                    struct Ping: Encodable { let lat: Double; let lng: Double }
                    let ping = Ping(lat: (c.latitude * 10_000).rounded() / 10_000, lng: (c.longitude * 10_000).rounded() / 10_000)
                    if (try? await supabase.from("location_pings").insert(ping).execute()) != nil {
                        lastSent = (here, Date())
                    }
                }
            }
            try? await Task.sleep(for: .seconds(10))
        }
    }
}
