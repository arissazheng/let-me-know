import AuthenticationServices
import Foundation
import Observation
import Supabase

/// Sign in with a UC Berkeley Google account (F1).
@MainActor
@Observable
final class AuthModel {
    private(set) var isSignedIn = supabase.auth.currentSession != nil
    private(set) var email: String? = supabase.auth.currentUser?.email
    /// Set when sign-in fails or a non-campus account tries to sign in.
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
                errorMessage = "Use your @\(AppConfig.campusEmailDomain) Google account."
                await signOut()
                continue
            }
            isSignedIn = session != nil
            email = session?.user.email
        }
    }

    static func isCampusEmail(_ email: String) -> Bool {
        email.trimmingCharacters(in: .whitespaces).lowercased().hasSuffix("@" + AppConfig.campusEmailDomain)
    }

    /// Opens Google's sign-in, asking for a berkeley.edu account.
    func signInWithGoogle(staySignedIn: Bool) async {
        errorMessage = nil
        UserDefaults.standard.set(staySignedIn, forKey: Self.staySignedInKey)
        do {
            _ = try await supabase.auth.signInWithOAuth(
                provider: .google,
                redirectTo: AppConfig.signInRedirect,
                queryParams: [(name: "hd", value: AppConfig.campusEmailDomain), (name: "prompt", value: "select_account")]
            )
        } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
            return
        } catch {
            errorMessage = error.localizedDescription.contains("berkeley.edu")
                ? "Use your @\(AppConfig.campusEmailDomain) Google account."
                : "Couldn't sign in: \(error.localizedDescription)"
        }
    }

    func signOut() async {
        try? await supabase.auth.signOut()
    }
}
