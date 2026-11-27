import Foundation
import Observation
import Supabase

/// Keeps favorites, recent searches, and settings with the student's account (user_data table), so
/// signing back in with the same email, on any phone or the web, brings them back.
@MainActor
final class AccountSync {
    static let shared = AccountSync()

    /// Settings that follow the account, with their defaults.
    static let preferenceDefaults: [String: Bool] = [
        PreferenceKey.avoidIncidents: true,
        PreferenceKey.avoidPoorLighting: true,
        PreferenceKey.preferBusierStreets: true,
        PreferenceKey.shareLocation: false,
        PreferenceKey.showReports: true,
        PreferenceKey.showLightGlow: true,
        PreferenceKey.showPopulationGlow: true,
        PreferenceKey.notifyNewReports: false,
    ]

    private var userID: UUID?
    /// True while applying what the server sent, so it isn't sent straight back.
    private var isApplying = false
    private var lastPreferences: [String: Bool] = [:]
    private var pending: Task<Void, Never>?

    private struct Row: Codable {
        var userID: UUID
        var favorites: [SavedPlace]
        var recents: [SavedPlace]
        var preferences: [String: Bool]
        enum CodingKeys: String, CodingKey {
            case userID = "user_id"
            case favorites, recents, preferences
        }
    }

    /// Loads the account's data on sign-in and clears this phone's copy on sign-out.
    func observe() async {
        Task {
            for await _ in NotificationCenter.default.notifications(named: UserDefaults.didChangeNotification) {
                if currentPreferences != lastPreferences { save() }
            }
        }
        for await (_, session) in supabase.auth.authStateChanges {
            let id = session?.user.id
            guard id != userID else { continue }
            userID = id
            if let id { await load(for: id) } else { clearLocal() }
        }
    }

    /// Sends the current favorites, recents, and settings (batched over half a second).
    func save() {
        guard !isApplying, let userID else { return }
        pending?.cancel()
        pending = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            let row = Row(userID: userID, favorites: SavedPlaces.shared.favorites, recents: SavedPlaces.shared.recents, preferences: currentPreferences)
            lastPreferences = row.preferences
            _ = try? await supabase.from("user_data").upsert(row).execute()
        }
    }

    private var currentPreferences: [String: Bool] {
        Self.preferenceDefaults.reduce(into: [:]) { result, item in
            result[item.key] = UserDefaults.standard.object(forKey: item.key) as? Bool ?? item.value
        }
    }

    private func load(for id: UUID) async {
        let rows: [Row]
        do {
            rows = try await supabase.from("user_data").select().eq("user_id", value: id).execute().value
        } catch {
            return // Offline or not set up yet: keep what's on the phone.
        }
        guard let row = rows.first else {
            save() // First sign-in: start the account from what's on this phone.
            return
        }
        isApplying = true
        SavedPlaces.shared.replace(favorites: row.favorites, recents: row.recents)
        for (key, value) in row.preferences where Self.preferenceDefaults[key] != nil {
            UserDefaults.standard.set(value, forKey: key)
        }
        lastPreferences = currentPreferences
        isApplying = false
    }

    /// The next student to sign in on this phone starts with nothing of the last one's.
    private func clearLocal() {
        isApplying = true
        SavedPlaces.shared.replace(favorites: [], recents: [])
        for key in Self.preferenceDefaults.keys { UserDefaults.standard.removeObject(forKey: key) }
        lastPreferences = currentPreferences
        isApplying = false
    }
}
