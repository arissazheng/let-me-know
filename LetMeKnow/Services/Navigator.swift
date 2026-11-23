import AVFoundation
import CoreLocation
import Observation

/// Turn-by-turn guidance along a SafeRoute: progress, the next turn, spoken
/// instructions, arrival, and detecting when the student has walked off the route.
@MainActor
@Observable
final class Navigator {
    private(set) var route: SafeRoute?
    /// The upcoming step (or the arrival step near the end).
    private(set) var nextManeuver: Maneuver?
    private(set) var metersToManeuver: Double = 0
    private(set) var remainingMeters: Double = 0
    private(set) var remainingSeconds: Double = 0
    private(set) var hasArrived = false
    var isMuted = false

    var isActive: Bool { route != nil }

    /// Distance along the path at each vertex.
    private var cumulative: [Double] = []
    private var progressIndex = 0
    private var offRouteFixes = 0
    private var spokenManeuver: Int?
    private let speech = AVSpeechSynthesizer()

    func start(_ route: SafeRoute) {
        load(route)
        hasArrived = false
        if let first = route.maneuvers.first { speak(first.instruction) }
    }

    /// Swap in a re-planned route without leaving navigation.
    func replace(with route: SafeRoute) {
        guard isActive else { return }
        load(route)
    }

    func stop() {
        route = nil
        nextManeuver = nil
        hasArrived = false
        speech.stopSpeaking(at: .immediate)
    }

    /// Updates progress for a new location fix. Returns true when the student has been
    /// off the route for two fixes in a row and the route should be re-planned.
    func update(location: CLLocationCoordinate2D) -> Bool {
        guard let route, route.path.count > 1, !hasArrived else { return false }
        let (along, offBy, index) = project(location, onto: route.path)
        progressIndex = index

        let total = cumulative.last ?? route.meters
        remainingMeters = max(total - along, 0)
        remainingSeconds = total > 0 ? route.seconds * remainingMeters / total : 0

        if remainingMeters < 20 {
            hasArrived = true
            nextManeuver = route.maneuvers.last
            metersToManeuver = 0
            speak("You have arrived.")
            return false
        }

        // The next step is the first one that begins ahead of the student.
        if let match = route.maneuvers.enumerated().first(where: { cumulative[$0.element.beginIndex] > along + 5 }) {
            let (i, step) = (match.offset, match.element)
            nextManeuver = step
            metersToManeuver = cumulative[step.beginIndex] - along
            if metersToManeuver < 40, spokenManeuver != i {
                spokenManeuver = i
                speak(step.instruction)
            }
        }

        offRouteFixes = offBy > 40 ? offRouteFixes + 1 : 0
        if offRouteFixes >= 2 {
            offRouteFixes = 0
            return true
        }
        return false
    }

    // MARK: - Private

    private func load(_ route: SafeRoute) {
        self.route = route
        cumulative = [0]
        for i in 1..<max(route.path.count, 1) {
            cumulative.append(cumulative[i - 1] + Self.meters(route.path[i - 1], route.path[i]))
        }
        progressIndex = 0
        offRouteFixes = 0
        spokenManeuver = 0
        nextManeuver = route.maneuvers.dropFirst().first ?? route.maneuvers.first
        metersToManeuver = nextManeuver.map { cumulative[$0.beginIndex] } ?? 0
        remainingMeters = cumulative.last ?? route.meters
        remainingSeconds = route.seconds
    }

    /// Projects `point` onto the nearest path segment at or after the last known progress.
    /// Returns the distance along the path, the distance off it, and the segment index.
    private func project(_ point: CLLocationCoordinate2D, onto path: [CLLocationCoordinate2D]) -> (Double, Double, Int) {
        var best = (along: 0.0, off: Double.greatestFiniteMagnitude, index: progressIndex)
        let metersPerDegLat = 111_320.0
        let metersPerDegLng = 111_320.0 * cos(point.latitude * .pi / 180)
        for i in max(progressIndex - 2, 0)..<(path.count - 1) {
            let a = path[i], b = path[i + 1]
            let ax = (a.longitude - point.longitude) * metersPerDegLng, ay = (a.latitude - point.latitude) * metersPerDegLat
            let bx = (b.longitude - point.longitude) * metersPerDegLng, by = (b.latitude - point.latitude) * metersPerDegLat
            let dx = bx - ax, dy = by - ay
            let lengthSquared = dx * dx + dy * dy
            let t = lengthSquared > 0 ? min(max(-(ax * dx + ay * dy) / lengthSquared, 0), 1) : 0
            let px = ax + t * dx, py = ay + t * dy
            let off = (px * px + py * py).squareRoot()
            if off < best.off {
                best = (cumulative[i] + t * (cumulative[i + 1] - cumulative[i]), off, i)
            }
        }
        return (best.along, best.off, best.index)
    }

    private func speak(_ text: String) {
        guard !isMuted else { return }
        speech.speak(AVSpeechUtterance(string: text))
    }

    private static func meters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }
}
