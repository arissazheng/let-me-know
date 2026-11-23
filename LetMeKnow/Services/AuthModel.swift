import Foundation
import Observation
import Supabase

/// Campus-email sign in with an emailed link (F1).
@MainActor
@Observable
final class AuthModel {
    private(set) var isSignedIn = supabase.auth.currentSession != nil
    private(set) var email: String? = supabase.auth.currentUser?.email

    func observe() async {
        for await (_, session) in supabase.auth.authStateChanges {
            isSignedIn = session != nil
            email = session?.user.email
        }
    }

    static func isCampusEmail(_ email: String) -> Bool {
        email.trimmingCharacters(in: .whitespaces).lowercased().hasSuffix("@" + AppConfig.campusEmailDomain)
    }

    /// Emails a sign-in link that opens the app at `AppConfig.signInRedirect`.
    func sendLink(to email: String) async throws {
        try await supabase.auth.signInWithOTP(
            email: email.trimmingCharacters(in: .whitespaces).lowercased(),
            redirectTo: AppConfig.signInRedirect
        )
    }

    /// Set when an emailed link opens the app but can't complete sign-in.
    var linkError: String?

    /// Completes sign-in when the emailed link opens the app.
    func handle(_ url: URL) async {
        do {
            _ = try await supabase.auth.session(from: url)
            linkError = nil
        } catch {
            linkError = "That sign-in link didn't work (\(error.localizedDescription)). Send a new one."
        }
    }

    func signOut() async {
        try? await supabase.auth.signOut()
    }
}
