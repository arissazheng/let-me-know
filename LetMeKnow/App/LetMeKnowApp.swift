import GoogleMaps
import GooglePlacesSwift
import SwiftUI
import UserNotifications

@main
struct LetMeKnowApp: App {
    @State private var auth = AuthModel()

    init() {
        GMSServices.provideAPIKey(AppConfig.googleMapsAPIKey)
        _ = PlacesClient.provideAPIKey(AppConfig.googleMapsAPIKey)
        UNUserNotificationCenter.current().delegate = Notifier.shared
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if auth.isSignedIn {
                    MapScreen()
                } else {
                    SignInView()
                }
            }
            .environment(auth)
            .task { await auth.observe() }
            .task { await AccountSync.shared.observe() }
            .onOpenURL { url in
                Task { await auth.handle(url) }
            }
        }
    }
}
