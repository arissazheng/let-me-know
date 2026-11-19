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

    /// Refreshes the aggregate every two minutes while the map is open.
    func keepFresh() async {
        while !Task.isCancelled {
            await load()
            try? await Task.sleep(for: .seconds(120))
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

    /// Sends an anonymous ping (rounded to ~11 m) every three minutes while sharing is on.
    func sharePings(from location: LocationManager) async {
        while !Task.isCancelled {
            if let c = location.coordinate {
                struct Ping: Encodable { let lat: Double; let lng: Double }
                let ping = Ping(lat: (c.latitude * 10_000).rounded() / 10_000, lng: (c.longitude * 10_000).rounded() / 10_000)
                _ = try? await supabase.from("location_pings").insert(ping).execute()
            }
            try? await Task.sleep(for: .seconds(180))
        }
    }
}
