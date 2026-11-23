import CoreLocation
import Foundation

/// A walking route scored for safety (F6).
struct SafeRoute: Identifiable, Equatable {
    let id = UUID()
    let path: [CLLocationCoordinate2D]
    let meters: Double
    let seconds: Double
    /// Share of the route within ~35 m of a city streetlight.
    let litFraction: Double
    /// 0 (empty) … 1 (busy), from population pings.
    let crowdLevel: Double
    /// Live reports within 50 m of the route.
    let nearbyReports: Int
    let score: Double
    /// Turn-by-turn steps, in order.
    let maneuvers: [Maneuver]

    static func == (lhs: SafeRoute, rhs: SafeRoute) -> Bool { lhs.id == rhs.id }

    /// Whether `point` lies within `meters` of this route.
    func passes(near point: CLLocationCoordinate2D, within meters: CLLocationDistance) -> Bool {
        let target = CLLocation(latitude: point.latitude, longitude: point.longitude)
        return RouteService.densify(path).contains {
            CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: target) <= meters
        }
    }
}

/// One turn-by-turn step from Valhalla.
struct Maneuver {
    /// Valhalla maneuver type (e.g. 10 = right, 15 = left, 4–6 = arrive).
    let type: Int
    let instruction: String
    /// Index into the route path where this step begins.
    let beginIndex: Int

    var isArrival: Bool { (4...6).contains(type) }

    /// SF Symbol for the turn arrow.
    var symbol: String {
        switch type {
        case 4, 5, 6: "mappin.circle.fill"
        case 9, 20, 23: "arrow.up.right"
        case 21, 24: "arrow.up.left"
        case 10, 11: "arrow.turn.up.right"
        case 12, 13: "arrow.uturn.down"
        case 14, 15: "arrow.turn.up.left"
        case 16: "arrow.up.left"
        default: "arrow.up"
        }
    }
}

enum RouteError: LocalizedError {
    case noRoute(String)

    var errorDescription: String? {
        switch self {
        case .noRoute(let message): "No walking route found. \(message)"
        }
    }
}

/// Valhalla pedestrian routing that avoids live incidents and prefers lit streets,
/// then ranks the alternatives by lighting, crowds, and nearby reports.
enum RouteService {
    static func routes(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        reports: [Report],
        crowdLevel: (CLLocationCoordinate2D) -> Double,
        preferences: RoutePreferences
    ) async throws -> [SafeRoute] {
        let endpoints = [origin, destination].map { CLLocation(latitude: $0.latitude, longitude: $0.longitude) }
        // Valhalla can't exclude an area that contains the start or end, so skip those reports.
        let avoidable = preferences.avoidIncidents ? reports.filter { report in
            let here = CLLocation(latitude: report.lat, longitude: report.lng)
            return endpoints.allSatisfy { $0.distance(from: here) > 60 }
        } : []

        var raw: [ValhallaTrip]
        do {
            raw = try await request(origin, destination, avoiding: avoidable, preferLit: preferences.avoidPoorLighting)
        } catch {
            // If avoiding every incident leaves no path, fall back to scoring unrestricted routes.
            guard !avoidable.isEmpty else { throw error }
            raw = try await request(origin, destination, avoiding: [], preferLit: preferences.avoidPoorLighting)
        }

        let lights = StreetlightIndex.shared
        return raw.map { trip in
            let samples = densify(trip.path)
            let lit = samples.isEmpty ? 0 : Double(samples.filter { lights.isLit($0) }.count) / Double(samples.count)
            let crowd = samples.isEmpty ? 0 : samples.map(crowdLevel).reduce(0, +) / Double(samples.count)
            let nearby = reports.filter { report in
                let here = CLLocation(latitude: report.lat, longitude: report.lng)
                return samples.contains { CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: here) <= 50 }
            }.count

            var score = trip.seconds / 60
            if preferences.avoidIncidents { score += Double(nearby) * 100 }
            if preferences.avoidPoorLighting { score += (1 - lit) * 50 }
            if preferences.preferBusierStreets { score += (1 - crowd) * 30 }

            return SafeRoute(
                path: trip.path, meters: trip.meters, seconds: trip.seconds,
                litFraction: lit, crowdLevel: crowd, nearbyReports: nearby, score: score,
                maneuvers: trip.maneuvers
            )
        }
        .sorted { $0.score < $1.score }
    }

    // MARK: - Valhalla

    private struct ValhallaTrip {
        let path: [CLLocationCoordinate2D]
        let meters: Double
        let seconds: Double
        let maneuvers: [Maneuver]
    }

    private static func request(
        _ origin: CLLocationCoordinate2D,
        _ destination: CLLocationCoordinate2D,
        avoiding reports: [Report],
        preferLit: Bool
    ) async throws -> [ValhallaTrip] {
        let body: [String: Any] = [
            "locations": [
                ["lat": origin.latitude, "lon": origin.longitude],
                ["lat": destination.latitude, "lon": destination.longitude],
            ],
            "costing": "pedestrian",
            "costing_options": ["pedestrian": ["use_lit": preferLit ? 1.0 : 0.0]],
            "exclude_polygons": reports.map { square(around: $0.coordinate, halfSide: 40) },
            "alternates": 2,
            "units": "kilometers",
        ]
        var urlRequest = URLRequest(url: AppConfig.valhallaURL.appendingPathComponent("route"))
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: urlRequest)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
        guard let trip = json["trip"] as? [String: Any] else {
            throw RouteError.noRoute(json["error"] as? String ?? "")
        }
        let alternates = (json["alternates"] as? [[String: Any]] ?? []).compactMap { $0["trip"] as? [String: Any] }
        return ([trip] + alternates).compactMap(parse)
    }

    private static func parse(_ trip: [String: Any]) -> ValhallaTrip? {
        guard let summary = trip["summary"] as? [String: Any],
              let km = summary["length"] as? Double,
              let seconds = summary["time"] as? Double,
              let legs = trip["legs"] as? [[String: Any]]
        else { return nil }
        // Two locations → a single leg, so maneuver shape indices index straight into `path`.
        let path = legs.compactMap { $0["shape"] as? String }.flatMap(decodePolyline6)
        let maneuvers = (legs.first?["maneuvers"] as? [[String: Any]] ?? []).compactMap { m -> Maneuver? in
            guard let type = m["type"] as? Int, let text = m["instruction"] as? String,
                  let begin = m["begin_shape_index"] as? Int else { return nil }
            return Maneuver(type: type, instruction: text, beginIndex: min(begin, max(path.count - 1, 0)))
        }
        return ValhallaTrip(path: path, meters: km * 1000, seconds: seconds, maneuvers: maneuvers)
    }

    /// Closed lon/lat ring, as Valhalla's exclude_polygons expects.
    private static func square(around c: CLLocationCoordinate2D, halfSide meters: Double) -> [[Double]] {
        let dLat = meters / 111_320
        let dLng = meters / (111_320 * cos(c.latitude * .pi / 180))
        return [
            [c.longitude - dLng, c.latitude - dLat],
            [c.longitude + dLng, c.latitude - dLat],
            [c.longitude + dLng, c.latitude + dLat],
            [c.longitude - dLng, c.latitude + dLat],
            [c.longitude - dLng, c.latitude - dLat],
        ]
    }

    /// Decodes Valhalla's precision-6 encoded polyline.
    static func decodePolyline6(_ encoded: String) -> [CLLocationCoordinate2D] {
        var coordinates: [CLLocationCoordinate2D] = []
        var index = encoded.unicodeScalars.startIndex
        let scalars = encoded.unicodeScalars
        var lat = 0
        var lng = 0

        func nextValue() -> Int? {
            var result = 0
            var shift = 0
            while index < scalars.endIndex {
                let byte = Int(scalars[index].value) - 63
                index = scalars.index(after: index)
                result |= (byte & 0x1F) << shift
                shift += 5
                if byte < 0x20 { return (result & 1) != 0 ? ~(result >> 1) : (result >> 1) }
            }
            return nil
        }

        while index < scalars.endIndex {
            guard let dLat = nextValue(), let dLng = nextValue() else { break }
            lat += dLat
            lng += dLng
            coordinates.append(.init(latitude: Double(lat) / 1e6, longitude: Double(lng) / 1e6))
        }
        return coordinates
    }

    /// Adds points so consecutive samples are at most `step` meters apart.
    static func densify(_ path: [CLLocationCoordinate2D], step: Double = 20) -> [CLLocationCoordinate2D] {
        guard var previous = path.first else { return [] }
        var result = [previous]
        for point in path.dropFirst() {
            let distance = CLLocation(latitude: previous.latitude, longitude: previous.longitude)
                .distance(from: CLLocation(latitude: point.latitude, longitude: point.longitude))
            let pieces = max(Int(distance / step), 1)
            for i in 1...pieces {
                let t = Double(i) / Double(pieces)
                result.append(.init(
                    latitude: previous.latitude + (point.latitude - previous.latitude) * t,
                    longitude: previous.longitude + (point.longitude - previous.longitude) * t
                ))
            }
            previous = point
        }
        return result
    }
}
