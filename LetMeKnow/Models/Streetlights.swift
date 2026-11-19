import CoreLocation
import Foundation

/// City of Berkeley streetlights (dataset dz4s-un9u), bundled as [[lat, lng, wattage], …].
struct Streetlight {
    let coordinate: CLLocationCoordinate2D
    let wattage: Int
}

final class StreetlightIndex {
    static let shared = StreetlightIndex()

    let lights: [Streetlight]
    private var grid: [GridKey: [CLLocationCoordinate2D]] = [:]

    private init() {
        guard let url = Bundle.main.url(forResource: "streetlights", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let rows = try? JSONDecoder().decode([[Double]].self, from: data)
        else {
            lights = []
            return
        }
        lights = rows.map { Streetlight(coordinate: .init(latitude: $0[0], longitude: $0[1]), wattage: Int($0[2])) }
        for light in lights {
            grid[GridKey(light.coordinate), default: []].append(light.coordinate)
        }
    }

    /// Whether any streetlight lies within `radius` meters of `point`.
    func isLit(_ point: CLLocationCoordinate2D, radius: CLLocationDistance = 35) -> Bool {
        let here = CLLocation(latitude: point.latitude, longitude: point.longitude)
        return GridKey(point).neighbors.contains { key in
            grid[key]?.contains { here.distance(from: CLLocation(latitude: $0.latitude, longitude: $0.longitude)) <= radius } ?? false
        }
    }
}

/// ~55 m grid cells for fast nearby lookups.
struct GridKey: Hashable {
    static let size = 0.0005
    let x: Int
    let y: Int

    init(_ c: CLLocationCoordinate2D) {
        x = Int((c.longitude / Self.size).rounded(.down))
        y = Int((c.latitude / Self.size).rounded(.down))
    }

    private init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    var neighbors: [GridKey] {
        (-1...1).flatMap { dx in (-1...1).map { dy in GridKey(x: x + dx, y: y + dy) } }
    }
}
