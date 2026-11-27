import SwiftUI

/// Top banner during navigation: the next turn and how far away it is.
struct TurnBanner: View {
    var maneuver: Maneuver?
    var meters: Double
    var hasArrived: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: hasArrived ? "mappin.circle.fill" : maneuver?.symbol ?? "arrow.up")
                .font(.system(size: 34, weight: .semibold))
                .frame(width: 44)
            VStack(alignment: .leading, spacing: 2) {
                if hasArrived {
                    Text("You've arrived").font(.title2.bold())
                } else {
                    Text(formatDistance(meters)).font(.title2.bold())
                    Text(maneuver?.instruction ?? "Continue").font(.subheadline.weight(.medium)).lineLimit(2)
                }
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(16)
        .glassEffect(.regular.tint(Color(GoogleMapView.safeGreen).opacity(0.85)), in: .rect(cornerRadius: 24))
    }
}

/// Bottom bar during navigation: time and distance left, arrival time, report, mute, and end.
struct NavigationBar: View {
    var remainingSeconds: Double
    var remainingMeters: Double
    @Binding var isMuted: Bool
    var onReport: () -> Void
    var onEnd: () -> Void

    var body: some View {
        GlassEffectContainer(spacing: 12) {
            HStack(spacing: 12) {
                Button("Report", systemImage: "exclamationmark.bubble.fill", action: onReport)
                    .labelStyle(.iconOnly)
                    .font(.title3)
                    .frame(width: 50, height: 50)
                    .foregroundStyle(.white)
                    .glassEffect(.regular.tint(.red).interactive(), in: .circle)

                VStack(spacing: 2) {
                    Text("\(max(Int((remainingSeconds / 60).rounded()), 1)) min")
                        .font(.title2.bold())
                        .foregroundStyle(.green)
                    Text("\(formatDistance(remainingMeters)) · \(Date().addingTimeInterval(remainingSeconds).formatted(date: .omitted, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                Button(isMuted ? "Unmute" : "Mute", systemImage: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill") {
                    isMuted.toggle()
                }
                .labelStyle(.iconOnly)
                .font(.title3)
                .frame(width: 50, height: 50)
                .glassEffect(.regular.interactive(), in: .circle)

                Button("End", systemImage: "xmark", action: onEnd)
                    .labelStyle(.iconOnly)
                    .font(.title3.weight(.semibold))
                    .frame(width: 50, height: 50)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
            .padding(10)
            .glassEffect(.regular, in: .capsule)
        }
    }
}

/// Feet under a tenth of a mile, otherwise miles — matching the route card.
func formatDistance(_ meters: Double) -> String {
    let miles = meters / 1609.34
    return miles < 0.1 ? "\(Int((meters * 3.281 / 10).rounded()) * 10) ft" : String(format: "%.1f mi", miles)
}

/// Shown when a new report near the route made it re-plan: what happened, where, and a way to read it.
struct RerouteAlert: View {
    var report: Report
    var onViewDetails: () -> Void
    var onClose: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Rerouted").font(.headline)
                Text(report.placeName.map { "Incident on \($0)" } ?? "Incident near your route")
                    .font(.subheadline)
                Button("View Details", action: onViewDetails)
                    .font(.subheadline.weight(.semibold))
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
            Button("Close", systemImage: "xmark", action: onClose)
                .labelStyle(.iconOnly)
                .font(.subheadline.weight(.semibold))
                .frame(width: 30, height: 30)
                .glassEffect(.regular.interactive(), in: .circle)
                .buttonStyle(.plain)
        }
        .padding(16)
        .glassEffect(.regular.tint(.orange.opacity(0.2)), in: .rect(cornerRadius: 24))
    }
}
