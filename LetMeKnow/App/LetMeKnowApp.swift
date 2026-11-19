import GoogleMaps
import GooglePlacesSwift
import SwiftUI

@main
struct LetMeKnowApp: App {
    @State private var auth = AuthModel()

    init() {
        GMSServices.provideAPIKey(AppConfig.googleMapsAPIKey)
        _ = PlacesClient.provideAPIKey(AppConfig.googleMapsAPIKey)
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
            .onOpenURL { url in
                Task { try? await auth.handle(url) }
            }
        }
    }
}
