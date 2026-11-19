import CoreLocation
import GooglePlacesSwift
import SwiftUI

/// F5: enter a destination.
struct SearchSheet: View {
    struct Destination {
        let name: String
        let coordinate: CLLocationCoordinate2D
    }

    var near: CLLocationCoordinate2D
    var onPick: (Destination) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var suggestions: [AutocompletePlaceSuggestion] = []
    @State private var errorMessage: String?
    @State private var token = AutocompleteSessionToken()

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
                ForEach(suggestions, id: \.placeID) { suggestion in
                    Button {
                        Task { await pick(suggestion) }
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(AttributedString(suggestion.attributedPrimaryText.characters))
                                .foregroundStyle(.primary)
                            if let secondary = suggestion.attributedSecondaryText {
                                Text(AttributedString(secondary.characters))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Where to?")
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

    private func pick(_ suggestion: AutocompletePlaceSuggestion) async {
        let request = FetchPlaceRequest(placeID: suggestion.placeID, placeProperties: [.coordinate, .displayName], sessionToken: token)
        switch await PlacesClient.shared.fetchPlace(with: request) {
        case .success(let place):
            token = AutocompleteSessionToken()
            onPick(Destination(name: place.displayName ?? String(suggestion.attributedPrimaryText.characters), coordinate: place.location))
            dismiss()
        case .failure(let error):
            errorMessage = "Couldn't load that place: \(error.localizedDescription)"
        }
    }
}
