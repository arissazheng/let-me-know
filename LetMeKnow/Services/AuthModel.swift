import AuthenticationServices
import Foundation
import Observation
import Supabase

/// Sign in with a school (.edu) Google account (F1).
@MainActor
@Observable
final class AuthModel {
    private(set) var isSignedIn = supabase.auth.currentSession != nil
    private(set) var email: String? = supabase.auth.currentUser?.email
    /// Set when sign-in fails or a non-school account tries to sign in.
    var errorMessage: String?

    /// Remembered on this phone; unchecked means the next launch starts signed out.
    private static let staySignedInKey = "staySignedIn"

    func observe() async {
        // "Stay logged in" was unchecked last time: this is a new launch, so end that session.
        if isSignedIn, UserDefaults.standard.object(forKey: Self.staySignedInKey) as? Bool == false {
            await signOut()
        }
        for await (_, session) in supabase.auth.authStateChanges {
            if let email = session?.user.email, !Self.isCampusEmail(email) {
                errorMessage = "Use your school (.edu) Google account."
                await signOut()
                continue
            }
            isSignedIn = session != nil
            email = session?.user.email
        }
    }

    static func isCampusEmail(_ email: String) -> Bool {
        Campus.domain(of: email.trimmingCharacters(in: .whitespaces)) != nil
    }

    /// Opens Google's sign-in. Any school's Google account works; the database refuses non-.edu ones.
    func signInWithGoogle(staySignedIn: Bool) async {
        errorMessage = nil
        UserDefaults.standard.set(staySignedIn, forKey: Self.staySignedInKey)
        do {
            _ = try await supabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: AppConfig.signInRedirect,
                queryParams: [(name: "prompt", value: "select_account")]
            )
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return
        } catch {
            errorMessage = error.localizedDescription.contains(".edu") || error.localizedDescription.contains("saving new user")
                ? "Use your school (.edu) Google account."
                : "Couldn't sign in: \(error.localizedDescription)"
        }
    }

    func signOut() async {
        try? await supabase.auth.signOut()
    }
}
