import SwiftUI

/// F6: the suggested routes and what makes each one safer.
struct RouteCard: View {
    var destinationName: String
    var routes: [SafeRoute]
    @Binding var selectedID: SafeRoute.ID?
    var onStart: () -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Safer route to")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(destinationName)
                        .font(.headline)
                        .lineLimit(1)
                }
                Spacer()
                Button("End", systemImage: "xmark", action: onClose)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
            }

            ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                Button {
                    selectedID = route.id
                } label: {
                    row(route, isBest: index == 0, isSelected: route.id == selectedID)
                }
                .buttonStyle(.plain)
            }

            Button(action: onStart) {
                Label("Start", systemImage: "location.north.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(.green)
            .disabled(selectedID == nil)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
    }

    private func row(_ route: SafeRoute, isBest: Bool, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(Int((route.seconds / 60).rounded())) min")
                    .font(.title3.bold())
                Text(Measurement(value: route.meters, unit: UnitLength.meters).formatted(.measurement(width: .abbreviated, usage: .road)))
                    .foregroundStyle(.secondary)
                Spacer()
                if isBest {
                    Text("Safest")
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                }
            }
            HStack(spacing: 6) {
                chip(
                    route.nearbyReports == 0 ? "No reports nearby" : "\(route.nearbyReports) report\(route.nearbyReports == 1 ? "" : "s") nearby",
                    systemImage: "exclamationmark.triangle.fill",
                    tint: route.nearbyReports == 0 ? .green : .red
                )
                chip("\(Int((route.litFraction * 100).rounded()))% lit", systemImage: "lightbulb.fill", tint: .yellow)
                chip(crowdLabel(route.crowdLevel), systemImage: "person.3.fill", tint: .blue)
            }
        }
        .padding(12)
        .background(isSelected ? Color.green.opacity(0.15) : .clear, in: .rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(isSelected ? Color.green : .clear, lineWidth: 1.5))
        .contentShape(.rect)
    }

    private func chip(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .glassEffect(.regular.tint(tint.opacity(0.25)), in: .capsule)
    }

    private func crowdLabel(_ level: Double) -> String {
        switch level {
        case ..<0.15: "Quiet"
        case ..<0.45: "Some people"
        default: "Busy"
        }
    }
}
