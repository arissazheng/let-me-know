import Foundation

/// Settings-page preferences (F7), persisted with @AppStorage under these keys.
enum PreferenceKey {
    static let avoidIncidents = "avoidIncidents"
    static let avoidPoorLighting = "avoidPoorLighting"
    static let preferBusierStreets = "preferBusierStreets"
    static let shareLocation = "shareLocation"
    static let showLightGlow = "showLightGlow"
    static let showPopulationGlow = "showPopulationGlow"
    static let showReports = "showReports"
}

struct RoutePreferences {
    var avoidIncidents = true
    var avoidPoorLighting = true
    var preferBusierStreets = true
}
