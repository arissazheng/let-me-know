import SwiftUI

/// F1: sign in with a verified campus email and a one-time code.
struct SignInView: View {
    @Environment(AuthModel.self) private var auth
    @State private var email = ""
    @State private var code = ""
    @State private var codeSent = false
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("Let Me Know")
                    .font(.largeTitle.bold())
                Text("Sign in with your campus email.")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                TextField("you@berkeley.edu", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(codeSent)
                    .padding()
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))

                if codeSent {
                    TextField("Code from your email", text: $code)
                        .textContentType(.oneTimeCode)
                        .keyboardType(.numberPad)
                        .padding()
                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await submit() }
            } label: {
                Group {
                    if isWorking {
                        ProgressView()
                    } else {
                        Text(codeSent ? "Sign In" : "Send Code")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .disabled(isWorking || (codeSent ? code.count < 6 : email.isEmpty))

            if codeSent {
                Button("Use a different email") {
                    codeSent = false
                    code = ""
                    errorMessage = nil
                }
                .font(.footnote)
            }
            Spacer()
        }
        .padding(24)
        .background(
            LinearGradient(
                colors: [Color(GoogleMapView.populationBlue).opacity(0.25), Color(GoogleMapView.lightYellow).opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }

    private func submit() async {
        errorMessage = nil
        guard AuthModel.isCampusEmail(email) else {
            errorMessage = "Use your @\(AppConfig.campusEmailDomain) email."
            return
        }
        isWorking = true
        defer { isWorking = false }
        do {
            if codeSent {
                try await auth.verify(email: email, code: code)
            } else {
                try await auth.sendCode(to: email)
                codeSent = true
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
