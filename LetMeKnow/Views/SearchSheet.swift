import CoreLocation
import GooglePlacesSwift
import SwiftUI

/// F5: enter a destination, with starred places and recent searches. Also used to type where an incident happened.
struct SearchSheet: View {
    struct Destination {
        let name: String
        let coordinate: CLLocationCoordinate2D
    }

    var title = "Where to?"
    var near: CLLocationCoordinate2D
    var onPick: (Destination) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var suggestions: [AutocompletePlaceSuggestion] = []
    @State private var errorMessage: String?
    @State private var token = AutocompleteSessionToken()
    @State private var saved = SavedPlaces.shared

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    savedSections
                } else {
                    ForEach(suggestions, id: \.placeID) { suggestion in
                        let name = String(suggestion.attributedPrimaryText.characters)
                        HStack {
                            Button {
                                Task { if let place = await fetch(suggestion) { choose(place) } }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(name)
                                        .foregroundStyle(.primary)
                                    if let secondary = suggestion.attributedSecondaryText {
                                        Text(AttributedString(secondary.characters))
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            starButton(isOn: saved.isFavorite(name)) {
                                Task { if let place = await fetch(suggestion) { saved.toggleFavorite(place) } }
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search for a place")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", systemImage: "xmark") { dismiss() }
                }
            }
            .task(id: query) { await search() }
        }
    }

    /// Before typing: starred places as chips, then recent searches.
    @ViewBuilder
    private var savedSections: some View {
        if !saved.favorites.isEmpty {
            Section("Favorites") {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(saved.favorites) { place in
                            Button { choose(place) } label: {
                                Label(place.name, systemImage: "star.fill")
                                    .font(.subheadline.weight(.medium))
                                    .lineLimit(1)
                            }
                            .buttonStyle(.glass)
                            .contextMenu {
                                Button("Remove from Favorites", systemImage: "star.slash", role: .destructive) {
                                    saved.toggleFavorite(place)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
            }
        }
        if !saved.recents.isEmpty {
            Section("Recent") {
                ForEach(saved.recents) { place in
                    HStack {
                        Button { choose(place) } label: {
                            Label(place.name, systemImage: "clock")
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        starButton(isOn: saved.isFavorite(place.name)) { saved.toggleFavorite(place) }
                    }
                    .swipeActions {
                        Button("Remove", systemImage: "trash", role: .destructive) { saved.removeRecent(place) }
                    }
                }
            }
        }
    }

    private func starButton(isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(isOn ? "Remove from Favorites" : "Add to Favorites", systemImage: isOn ? "star.fill" : "star", action: action)
            .labelStyle(.iconOnly)
            .foregroundStyle(isOn ? .yellow : .secondary)
            .buttonStyle(.borderless)
    }

    private func choose(_ place: SavedPlace) {
        saved.addRecent(place)
        onPick(Destination(name: place.name, coordinate: place.coordinate))
        dismiss()
    }

    private func search() async {
        let text = query.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else {
            suggestions = []
            return
        }
        try? await Task.sleep(for: .milliseconds(250))
        guard !Task.isCancelled else { return }
        let filter = AutocompleteFilter(coordinateRegionBias: CircularCoordinateRegion(center: near, radius: 3000))
        let request = AutocompleteRequest(query: text, sessionToken: token, filter: filter)
        switch await PlacesClient.shared.fetchAutocompleteSuggestions(with: request) {
        case .success(let results):
            errorMessage = nil
            suggestions = results.compactMap {
                if case .place(let place) = $0 { place } else { nil }
            }
        case .failure(let error):
            errorMessage = "Search unavailable: \(error.localizedDescription)"
        }
    }

    private func fetch(_ suggestion: AutocompletePlaceSuggestion) async -> SavedPlace? {
        let request = FetchPlaceRequest(placeID: suggestion.placeID, placeProperties: [.coordinate, .displayName], sessionToken: token)
        switch await PlacesClient.shared.fetchPlace(with: request) {
        case .success(let place):
            token = AutocompleteSessionToken()
            return SavedPlace(name: place.displayName ?? String(suggestion.attributedPrimaryText.characters), coordinate: place.location)
        case .failure(let error):
            errorMessage = "Couldn't load that place: \(error.localizedDescription)"
            return nil
        }
    }
}
