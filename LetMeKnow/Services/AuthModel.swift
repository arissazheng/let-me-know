import Foundation
import Observation
import Supabase

/// Campus-email sign in with a one-time code (F1).
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

    func sendCode(to email: String) async throws {
        try await supabase.auth.signInWithOTP(email: email.trimmingCharacters(in: .whitespaces).lowercased())
    }

    func verify(email: String, code: String) async throws {
        _ = try await supabase.auth.verifyOTP(
            email: email.trimmingCharacters(in: .whitespaces).lowercased(),
            token: code.trimmingCharacters(in: .whitespaces),
            type: .email
        )
    }

    func signOut() async {
        try? await supabase.auth.signOut()
    }
}
