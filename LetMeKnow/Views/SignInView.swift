import SwiftUI

/// F1: sign in with a verified campus email via an emailed link.
struct SignInView: View {
    @Environment(AuthModel.self) private var auth
    @State private var email = ""
    @State private var linkSent = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: linkSent ? "envelope.open.fill" : "figure.walk.motion")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                    .contentTransition(.symbolEffect(.replace))
                Text(linkSent ? "Check your email" : "Let Me Know")
                    .font(.largeTitle.bold())
                Text(linkSent ? "Tap the sign-in link we sent to \(email) on this phone." : "Sign in with your campus email.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if !linkSent {
                TextField("you@berkeley.edu", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await send() }
            } label: {
                Group {
                    if isWorking {
                        ProgressView()
                    } else {
                        Text(linkSent ? "Resend Link" : "Email Me a Sign-In Link")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .disabled(isWorking || email.isEmpty)

            if linkSent {
                Button("Use a different email") {
                    linkSent = false
                    errorMessage = nil
                }
                .font(.footnote)
            }
            Spacer()
        }
        .padding(24)
        .animation(.snappy, value: linkSent)
        .background(
            LinearGradient(
                colors: [Color(GoogleMapView.populationBlue).opacity(0.25), Color(GoogleMapView.lightYellow).opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }

    private func send() async {
        errorMessage = nil
        guard AuthModel.isCampusEmail(email) else {
            errorMessage = "Use your @\(AppConfig.campusEmailDomain) email."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            try await auth.sendLink(to: email)
            linkSent = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
