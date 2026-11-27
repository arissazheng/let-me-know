import CoreLocation
import Foundation
import Observation

/// A place the student starred or searched for, kept on this phone.
struct SavedPlace: Codable, Hashable, Identifiable {
    var name: String
    var lat: Double
    var lng: Double

    var id: String { name }
    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }

    init(name: String, coordinate: CLLocationCoordinate2D) {
        self.name = name
        lat = coordinate.latitude
        lng = coordinate.longitude
    }
}

/// Favorite places and recent searches for the search sheet, saved on the device.
@Observable
final class SavedPlaces {
    static let shared = SavedPlaces()
    private static let recentLimit = 10

    private(set) var favorites: [SavedPlace] = load("savedPlaces.favorites") {
        didSet { save(favorites, "savedPlaces.favorites") }
    }
    private(set) var recents: [SavedPlace] = load("savedPlaces.recents") {
        didSet { save(recents, "savedPlaces.recents") }
    }

    func isFavorite(_ name: String) -> Bool { favorites.contains { $0.name == name } }

    func toggleFavorite(_ place: SavedPlace) {
        if isFavorite(place.name) { favorites.removeAll { $0.name == place.name } } else { favorites.append(place) }
    }

    /// Newest first, without duplicates.
    func addRecent(_ place: SavedPlace) {
        recents = Array(([place] + recents.filter { $0.name != place.name }).prefix(Self.recentLimit))
    }

    func removeRecent(_ place: SavedPlace) { recents.removeAll { $0.name == place.name } }

    private static func load(_ key: String) -> [SavedPlace] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        return (try? JSONDecoder().decode([SavedPlace].self, from: data)) ?? []
    }

    private func save(_ places: [SavedPlace], _ key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(places), forKey: key)
    }
}
