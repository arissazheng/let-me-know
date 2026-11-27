import SwiftUI

/// F7: the menu — the incident tracker, campus resources, notifications, route preferences, and
/// the opt-in for preference-based location tracking.
struct SettingsView: View {
    @Environment(AuthModel.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @AppStorage(PreferenceKey.avoidIncidents) private var avoidIncidents = true
    @AppStorage(PreferenceKey.avoidPoorLighting) private var avoidPoorLighting = true
    @AppStorage(PreferenceKey.preferBusierStreets) private var preferBusierStreets = true
    @AppStorage(PreferenceKey.shareLocation) private var shareLocation = false
    @AppStorage(PreferenceKey.notifyNewReports) private var notifyNewReports = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink { IncidentTrackerView() } label: {
                        Label("Incident Tracker", systemImage: "tablecells")
                    }
                    NavigationLink { SafetyResourcesView() } label: {
                        Label("Safety Resources", systemImage: "cross.case")
                    }
                    NavigationLink { AboutView() } label: {
                        Label("About Us", systemImage: "info.circle")
                    }
                }

                Section {
                    Toggle("New incident reports", systemImage: "bell.badge", isOn: $notifyNewReports)
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Get a notification whenever a student reports an incident around campus.")
                }

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

                Section {
                    if let email = auth.email {
                        LabeledContent("Signed in as", value: email)
                    }
                    Button("Sign Out", role: .destructive) {
                        Task { await auth.signOut() }
                    }
                } footer: {
                    Text("Favorites, recent searches, and these settings are saved to your account.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", systemImage: "checkmark") { dismiss() }
                }
            }
            .onChange(of: notifyNewReports) { _, on in
                guard on else { return }
                Task { if await !Notifier.shared.requestPermission() { notifyNewReports = false } }
            }
        }
    }}
