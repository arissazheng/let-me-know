import Foundation
import Supabase

/// Values injected from Config/Secrets.xcconfig through Info.plist.
enum AppConfig {
    static let googleMapsAPIKey = value("GoogleMapsAPIKey")
    static let supabaseURL = URL(string: value("SupabaseURL"))!
    static let supabaseAnonKey = value("SupabaseAnonKey")
    static let valhallaURL = URL(string: value("ValhallaURL"))!

    /// Only verified campus emails can sign in (F1).
    static let campusEmailDomain = "berkeley.edu"

    private static func value(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else {
            fatalError("Missing \(key). Copy Config/Secrets.example.xcconfig to Config/Secrets.xcconfig and fill it in.")
        }
        return value
    }
}

let supabase = SupabaseClient(supabaseURL: AppConfig.supabaseURL, supabaseKey: AppConfig.supabaseAnonKey)
