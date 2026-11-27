import SwiftUI

/// F1: sign in with a UC Berkeley Google account.
struct SignInView: View {
    @Environment(AuthModel.self) private var auth
    @State private var staySignedIn = true
    @State private var isWorking = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 8) {
                Image(systemName: "figure.walk.motion")
                    .font(.system(size: 56))
                    .foregroundStyle(.tint)
                Text("Let Me Know")
                    .font(.largeTitle.bold())
                Text("Sign in with your @\(AppConfig.campusEmailDomain) Google account.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let errorMessage = auth.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task {
                    isWorking = true
                    await auth.signInWithGoogle(staySignedIn: staySignedIn)
                    isWorking = false
                }
            } label: {
                Group {
                    if isWorking {
                        ProgressView()
                    } else {
                        Label("Continue with Google", systemImage: "person.crop.circle.badge.checkmark")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .disabled(isWorking)

            Toggle("Stay logged in", isOn: $staySignedIn)
                .toggleStyle(CheckboxToggleStyle())
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
}

/// A tappable checkbox with its label, since iOS toggles are switches.
private struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundStyle(configuration.isOn ? Color.accentColor : .secondary)
                configuration.label
                    .foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(configuration.isOn ? .isSelected : [])
    }
}
