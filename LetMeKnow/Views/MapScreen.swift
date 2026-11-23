import CoreLocation
import SwiftUI

/// The home screen: map, live reports, glows, search, safer routes, and reporting.
struct MapScreen: View {
    @State private var reportsStore = ReportsStore()
    @State private var population = PopulationStore()
    @State private var location = LocationManager()
    @State private var navigator = Navigator()
    /// During navigation the camera follows the student until they move the map themselves.
    @State private var isFollowing = true

    @AppStorage(PreferenceKey.avoidIncidents) private var avoidIncidents = true
    @AppStorage(PreferenceKey.avoidPoorLighting) private var avoidPoorLighting = true
    @AppStorage(PreferenceKey.preferBusierStreets) private var preferBusierStreets = true
    @AppStorage(PreferenceKey.shareLocation) private var shareLocation = false
    @AppStorage(PreferenceKey.showReports) private var showReports = true
    @AppStorage(PreferenceKey.showLightGlow) private var showLightGlow = true
    @AppStorage(PreferenceKey.showPopulationGlow) private var showPopulationGlow = true

    @State private var cameraCenter = GoogleMapView.berkeley
    @State private var focus: CLLocationCoordinate2D?
    @State private var focusToken = 0

    @State private var selectedReport: Report?
    @State private var isPlacingReport = false
    @State private var isWritingReport = false
    @State private var reportCoordinate = GoogleMapView.berkeley
    @State private var isSearching = false
    @State private var isShowingSettings = false

    @State private var destination: SearchSheet.Destination?
    @State private var routes: [SafeRoute] = []
    @State private var selectedRouteID: SafeRoute.ID?
    @State private var isRouting = false
    @State private var routeError: String?
    @State private var banner: String?

    private var preferences: RoutePreferences {
        RoutePreferences(avoidIncidents: avoidIncidents, avoidPoorLighting: avoidPoorLighting, preferBusierStreets: preferBusierStreets)
    }

    var body: some View {
        ZStack {
            GoogleMapView(
                reports: reportsStore.reports,
                populationCells: population.cells,
                showReports: showReports,
                showLightGlow: showLightGlow,
                showPopulationGlow: showPopulationGlow,
                routes: navigator.route.map { [$0] } ?? routes,
                selectedRouteID: navigator.route?.id ?? selectedRouteID,
                destination: destination?.coordinate,
                focus: focus,
                focusToken: focusToken,
                follow: navigator.isActive && isFollowing ? location.coordinate.map { ($0, location.course, location.updateCount) } : nil,
                isNavigating: navigator.isActive,
                bottomPadding: navigator.isActive ? 120 : destination == nil ? 110 : 390,
                onCameraIdle: { cameraCenter = $0 },
                onUserGesture: { if navigator.isActive { isFollowing = false } },
                onSelectReport: { selectedReport = $0 },
                onSelectRoute: { selectedRouteID = $0 }
            )
            .ignoresSafeArea()

            if isPlacingReport {
                Image(systemName: "mappin")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.red)
                    .shadow(radius: 4)
                    .offset(y: -22)
                    .allowsHitTesting(false)
            }

            VStack(spacing: 10) {
                if navigator.isActive {
                    TurnBanner(maneuver: navigator.nextManeuver, meters: navigator.metersToManeuver, hasArrived: navigator.hasArrived)
                } else {
                    topBar
                }
                if let banner {
                    Label(banner, systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassEffect(.regular.tint(.orange.opacity(0.35)), in: .capsule)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if let message = reportsStore.errorMessage ?? routeError {
                    Text(message)
                        .font(.footnote)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassEffect(.regular.tint(.red.opacity(0.25)), in: .capsule)
                }
                Spacer()
                bottomBar
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .animation(.snappy, value: banner)
            .animation(.snappy, value: isFollowing)
        }
        .sheet(item: $selectedReport) { ReportDetailSheet(report: $0) }
        .sheet(isPresented: $isSearching) {
            SearchSheet(near: location.coordinate ?? cameraCenter) { picked in
                destination = picked
                Task { await planRoute() }
            }
        }
        .sheet(isPresented: $isWritingReport) {
            NewReportSheet(coordinate: reportCoordinate) { text, media in
                try await reportsStore.submit(description: text, at: reportCoordinate, media: media)
                isPlacingReport = false
            }
        }
        .sheet(isPresented: $isShowingSettings) { SettingsView() }
        .task {
            location.start()
            await reportsStore.load()
        }
        .task { await reportsStore.listen() }
        .task { await population.keepFresh() }
        .task(id: shareLocation) {
            if shareLocation { await population.sharePings(from: location) }
        }
        .onChange(of: location.updateCount) {
            guard navigator.isActive, let here = location.coordinate else { return }
            if navigator.update(location: here) {
                Task {
                    await planRoute()
                    showBanner("Off route. Found a new safer route.")
                }
            }
        }
        .onChange(of: reportsStore.latestLiveReport) { _, report in
            guard let report else { return }
            rerouteIfNeeded(for: report)
        }
        .onChange(of: [avoidIncidents, avoidPoorLighting, preferBusierStreets]) {
            if destination != nil { Task { await planRoute() } }
        }
    }

    // MARK: - Bars

    private var topBar: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    isSearching = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                        Text(destination?.name ?? "Where to?")
                            .foregroundStyle(destination == nil ? .secondary : .primary)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 18)
                    .frame(height: 50)
                    .contentShape(.capsule)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .capsule)

                Menu {
                    Toggle("Reports", systemImage: "exclamationmark.triangle", isOn: $showReports)
                    Toggle("Streetlights", systemImage: "lightbulb", isOn: $showLightGlow)
                    Toggle("Students", systemImage: "person.3", isOn: $showPopulationGlow)
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.title3)
                        .frame(width: 50, height: 50)
                        .contentShape(.circle)
                }
                .buttonStyle(.plain)
                .glassEffect(.regular.interactive(), in: .circle)
            }
        }
    }

    @ViewBuilder
    private var bottomBar: some View {
        if isPlacingReport {
            VStack(spacing: 12) {
                Text("Move the map to place the pin where it happened.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                HStack {
                    Button("Cancel") { isPlacingReport = false }
                        .buttonStyle(.glass)
                    Spacer()
                    Button("Next") {
                        reportCoordinate = cameraCenter
                        isWritingReport = true
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.red)
                }
                .controlSize(.large)
            }
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 28))
        } else if navigator.isActive {
            if !isFollowing {
                Button {
                    isFollowing = true
                } label: {
                    Label("Re-center", systemImage: "location.north.fill")
                        .font(.headline)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity, alignment: .leading)
                .transition(.scale.combined(with: .opacity))
            }
            NavigationBar(
                remainingSeconds: navigator.remainingSeconds,
                remainingMeters: navigator.remainingMeters,
                isMuted: $navigator.isMuted,
                onReport: { isPlacingReport = true },
                onEnd: endRoute
            )
        } else if let destination {
            if isRouting {
                ProgressView("Finding a safer route…")
                    .padding(20)
                    .glassEffect(.regular, in: .capsule)
            } else if !routes.isEmpty {
                // Reporting stays available mid-route; the student is most likely to see something while walking.
                VStack(alignment: .trailing, spacing: 10) {
                    reportButton
                    RouteCard(
                        destinationName: destination.name,
                        routes: routes,
                        selectedID: $selectedRouteID,
                        onStart: startNavigation,
                        onClose: endRoute
                    )
                }
            } else {
                Button("Close", systemImage: "xmark", action: endRoute)
                    .buttonStyle(.glass)
            }
        } else {
            legend
            GlassEffectContainer(spacing: 16) {
                HStack {
                    Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .frame(width: 50, height: 50)
                        .glassEffect(.regular.interactive(), in: .circle)

                    Spacer()

                    reportButton

                    Spacer()

                    Button("My Location", systemImage: "location.fill") {
                        focus = location.coordinate ?? GoogleMapView.berkeley
                        focusToken += 1
                    }
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .frame(width: 50, height: 50)
                    .glassEffect(.regular.interactive(), in: .circle)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var reportButton: some View {
        Button {
            isPlacingReport = true
        } label: {
            Label("Report", systemImage: "exclamationmark.bubble.fill")
                .font(.headline)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .tint(.red)
    }

    @ViewBuilder
    private var legend: some View {
        if showLightGlow || showPopulationGlow {
            HStack(spacing: 14) {
                if showLightGlow { legendItem("Streetlights", color: Color(GoogleMapView.lightYellow)) }
                if showPopulationGlow { legendItem("Students", color: Color(GoogleMapView.populationBlue)) }
            }
            .font(.caption.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .capsule)
        }
    }

    private func legendItem(_ title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 10, height: 10).shadow(color: color, radius: 4)
            Text(title)
        }
    }

    // MARK: - Routing (F6, F8)

    private func planRoute() async {
        guard let destination else { return }
        guard let origin = location.coordinate else {
            routeError = "Turn on location to plan a route."
            return
        }
        isRouting = true
        routeError = nil
        defer { isRouting = false }
        do {
            routes = try await RouteService.routes(
                from: origin,
                to: destination.coordinate,
                reports: reportsStore.reports,
                crowdLevel: { population.crowdLevel(near: $0) },
                preferences: preferences
            )
            selectedRouteID = routes.first?.id
            // Mid-walk re-plans (new report or off route) continue guidance on the new route.
            if let best = routes.first { navigator.replace(with: best) }
        } catch {
            routes = []
            routeError = error.localizedDescription
        }
    }

    /// Routes self-correct when a new report lands near the route being shown.
    private func rerouteIfNeeded(for report: Report) {
        guard destination != nil,
              let current = navigator.route ?? routes.first(where: { $0.id == selectedRouteID }),
              current.passes(near: report.coordinate, within: 75)
        else { return }
        Task {
            await planRoute()
            showBanner("New report near your route. Route updated.")
        }
    }

    private func showBanner(_ text: String) {
        banner = text
        Task {
            try? await Task.sleep(for: .seconds(5))
            if banner == text { banner = nil }
        }
    }

    private func startNavigation() {
        guard let route = routes.first(where: { $0.id == selectedRouteID }) else { return }
        isFollowing = true
        navigator.start(route)
    }

    private func endRoute() {
        navigator.stop()
        destination = nil
        routes = []
        selectedRouteID = nil
        routeError = nil
    }
}
