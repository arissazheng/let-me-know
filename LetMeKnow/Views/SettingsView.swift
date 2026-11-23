import SwiftUI

/// F7: route preferences, plus the opt-in for preference-based location tracking.
struct SettingsView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @AppStorage(PreferenceKey.avoidIncidents) private var avoidIncidents = true
    @AppStorage(PreferenceKey.avoidPoorLighting) private var avoidPoorLighting = true
    @AppStorage(PreferenceKey.preferBusierStreets) private var preferBusierStreets = true
    @AppStorage(PreferenceKey.shareLocation) private var shareLocation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Avoid live incidents", systemImage: "exclamationmark.triangle", isOn: $avoidIncidents)
                    Toggle("Avoid poorly lit streets", systemImage: "lightbulb", isOn: $avoidPoorLighting)
                    Toggle("Prefer busier streets", systemImage: "person.3", isOn: $preferBusierStreets)
                } header: {
                    Text("Safer Routes")
                }

                Section {
                    Toggle("Share my location anonymously", systemImage: "location", isOn: $shareLocation)
                } header: {
                    Text("Population Map")
                } footer: {
                    Text("While the app is open, sends your approximate location (rounded to about 10 m) as you move, about once a minute. It's only used to show how crowded areas are, never who is where.")
                }

                Section("About the Data") {
                    LabeledContent("Streetlights", value: "City of Berkeley")
                    LabeledContent("Population", value: "Student pings + simulated")
                    LabeledContent("Routes", value: "Valhalla / OpenStreetMap")
                }

                Section {
                    if let email = auth.email {
                        LabeledContent("Signed in as", value: email)
                    }
                    Button("Sign Out", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
        }
    }
}
