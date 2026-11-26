import GoogleMaps
import GoogleMapsUtils
import SwiftUI

/// Google map with report pins (F3), the streetlight (yellow) and population (blue) glows,
/// and route polylines (F6).
struct GoogleMapView: UIViewRepresentable {
    var reports: [Report]
    var populationCells: [PopulationStore.Cell]
    var showReports: Bool
    var showLightGlow: Bool
    var showPopulationGlow: Bool
    var routes: [SafeRoute]
    var selectedRouteID: SafeRoute.ID?
    var destination: CLLocationCoordinate2D?
    /// Bump to move the camera to `focus`.
    var focus: CLLocationCoordinate2D?
    var focusToken: Int
    /// While navigating and following: keep the camera on the student, pointed along their direction of travel.
    var follow: (coordinate: CLLocationCoordinate2D, bearing: Double?, token: Int)?
    var isNavigating: Bool
    var bottomPadding: CGFloat
    var onCameraIdle: (CLLocationCoordinate2D) -> Void
    /// The student panned, zoomed, rotated, or tilted the map themselves.
    var onUserGesture: () -> Void
    var onSelectReport: (Report) -> Void
    var onSelectRoute: (SafeRoute.ID) -> Void

    static let berkeley = CLLocationCoordinate2D(latitude: 37.8690, longitude: -122.2595)
    /// Room kept clear above the camera target for the search bar.
    static let topPadding: CGFloat = 70
    static let lightYellow = UIColor(red: 1.0, green: 0.80, blue: 0.0, alpha: 1)
    static let populationBlue = UIColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 1)
    static let safeGreen = UIColor(red: 0.20, green: 0.78, blue: 0.35, alpha: 1)

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> GMSMapView {
        let options = GMSMapViewOptions()
        options.camera = GMSCameraPosition(latitude: Self.berkeley.latitude, longitude: Self.berkeley.longitude, zoom: 15.5)
        let map = GMSMapView(options: options)
        map.isMyLocationEnabled = true
        map.settings.compassButton = false
        map.delegate = context.coordinator

        let lights = context.coordinator.lightLayer
        lights.weightedData = StreetlightIndex.shared.lights.map {
            GMUWeightedLatLng(coordinate: $0.coordinate, intensity: Float(max($0.wattage, 20)) / 50)
        }
        return map
    }

    func updateUIView(_ map: GMSMapView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        map.padding = UIEdgeInsets(top: Self.topPadding, left: 0, bottom: bottomPadding, right: 0)

        coordinator.lightLayer.map = showLightGlow ? map : nil

        coordinator.updatePopulation(populationCells, visible: showPopulationGlow, on: map)
        coordinator.updateReports(showReports ? reports : [], on: map)
        coordinator.updateRoutes(routes, selected: selectedRouteID, destination: destination, on: map)

        if focusToken != coordinator.lastFocusToken, let focus {
            coordinator.lastFocusToken = focusToken
            map.animate(toLocation: focus)
        }

        if let follow {
            let resuming = !coordinator.isFollowing
            if resuming || follow.token != coordinator.lastFollowToken {
                coordinator.lastFollowToken = follow.token
                coordinator.isFollowing = true
                // Starting or re-centering snaps to a street-level, tilted view; later fixes keep the
                // student's own zoom and tilt and only move and turn the camera.
                map.animate(to: GMSCameraPosition(
                    target: follow.coordinate,
                    zoom: resuming ? 18 : map.camera.zoom,
                    bearing: follow.bearing ?? map.camera.bearing,
                    viewingAngle: resuming ? 45 : map.camera.viewingAngle
                ))
            }
        } else {
            coordinator.isFollowing = false
        }

        if coordinator.wasNavigating, !isNavigating {
            map.animate(to: GMSCameraPosition(target: map.camera.target, zoom: 16, bearing: 0, viewingAngle: 0))
        }
        coordinator.wasNavigating = isNavigating
    }

    final class Coordinator: NSObject, GMSMapViewDelegate {
        var parent: GoogleMapView
        var lastFocusToken = 0
        var lastFollowToken = -1
        var isFollowing = false
        var wasNavigating = false
        let lightLayer = Coordinator.glowLayer(color: GoogleMapView.lightYellow, radius: 50)
        let populationLayer: GMUHeatmapTileLayer = {
            let layer = Coordinator.glowLayer(color: GoogleMapView.populationBlue, radius: 50)
            layer.zIndex = 1  // draw students above streetlights
            return layer
        }()

        private var reportMarkers: [UUID: GMSMarker] = [:]
        private var routeLines: [GMSPolyline] = []
        private var destinationMarker: GMSMarker?
        private var drawnRoutes: [SafeRoute.ID] = []
        private var drawnSelection: SafeRoute.ID?
        private var populationCount = -1

        init(_ parent: GoogleMapView) { self.parent = parent }

        /// A heat map that fades from transparent to `color` — the "glow".
        static func glowLayer(color: UIColor, radius: UInt) -> GMUHeatmapTileLayer {
            let layer = GMUHeatmapTileLayer()
            layer.radius = radius
            layer.opacity = 0.85
            // Normalize against street-level zooms. The default (zoom 5–10) measures against
            // citywide clusters, which leaves single blocks too faint to see at zoom 15+.
            layer.minimumZoomIntensity = 16
            layer.maximumZoomIntensity = 18
            // Opacity rises steadily with density: sparse areas stay see-through with soft
            // edges, and only the densest clusters reach the fully saturated color.
            layer.gradient = GMUGradient(
                colors: [
                    color.withAlphaComponent(0.08),
                    color.withAlphaComponent(0.35),
                    color.withAlphaComponent(0.7),
                    color,
                ],
                startPoints: [0.02, 0.15, 0.4, 0.8],
                colorMapSize: 256
            )
            return layer
        }

        func updatePopulation(_ cells: [PopulationStore.Cell], visible: Bool, on map: GMSMapView) {
            if cells.count != populationCount {
                populationCount = cells.count
                populationLayer.weightedData = cells.map {
                    GMUWeightedLatLng(coordinate: $0.coordinate, intensity: Float($0.weight))
                }
                populationLayer.clearTileCache()
            }
            populationLayer.map = visible && !cells.isEmpty ? map : nil
        }

        func updateReports(_ reports: [Report], on map: GMSMapView) {
            let ids = Set(reports.map(\.id))
            for (id, marker) in reportMarkers where !ids.contains(id) {
                marker.map = nil
                reportMarkers[id] = nil
            }
            for report in reports where reportMarkers[report.id] == nil {
                let marker = GMSMarker(position: report.coordinate)
                marker.icon = GMSMarker.markerImage(with: .systemRed)
                marker.userData = report.id
                marker.zIndex = 2
                marker.map = map
                reportMarkers[report.id] = marker
            }
        }

        func updateRoutes(_ routes: [SafeRoute], selected: SafeRoute.ID?, destination: CLLocationCoordinate2D?, on map: GMSMapView) {
            let ids = routes.map(\.id)
            guard ids != drawnRoutes || selected != drawnSelection else { return }
            let isNewRouteSet = ids != drawnRoutes
            drawnRoutes = ids
            drawnSelection = selected

            routeLines.forEach { $0.map = nil }
            routeLines = []
            destinationMarker?.map = nil
            destinationMarker = nil

            // Draw alternates first so the selected route sits on top.
            for route in routes.filter({ $0.id != selected }) + routes.filter({ $0.id == selected }) {
                let path = GMSMutablePath()
                route.path.forEach { path.add($0) }
                let line = GMSPolyline(path: path)
                let isSelected = route.id == selected
                line.strokeColor = isSelected ? GoogleMapView.safeGreen : UIColor.systemGray.withAlphaComponent(0.7)
                line.strokeWidth = isSelected ? 7 : 5
                line.zIndex = isSelected ? 1 : 0
                line.isTappable = true
                line.userData = route.id
                line.map = map
                routeLines.append(line)
            }

            if let destination {
                let marker = GMSMarker(position: destination)
                marker.icon = GMSMarker.markerImage(with: GoogleMapView.safeGreen)
                marker.map = map
                destinationMarker = marker
            }

            if isNewRouteSet, !wasNavigating, let first = routes.first {
                let bounds = first.path.reduce(GMSCoordinateBounds()) { $0.includingCoordinate($1) }
                map.animate(with: GMSCameraUpdate.fit(bounds, withPadding: 60))
            }
        }

        func mapView(_ mapView: GMSMapView, didTap marker: GMSMarker) -> Bool {
            guard let id = marker.userData as? UUID, let report = parent.reports.first(where: { $0.id == id }) else { return false }
            parent.onSelectReport(report)
            return true
        }

        func mapView(_ mapView: GMSMapView, didTap overlay: GMSOverlay) {
            if let id = overlay.userData as? SafeRoute.ID { parent.onSelectRoute(id) }
        }

        func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
            if gesture { parent.onUserGesture() }
        }

        func mapView(_ mapView: GMSMapView, idleAt position: GMSCameraPosition) {
            parent.onCameraIdle(position.target)
        }
    }
}
