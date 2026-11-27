import Supabase
import SwiftUI

/// Every report around campus as a table, or just the ones this student filed.
struct IncidentTrackerView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case all = "All Reports"
        case mine = "My Reports"
        var id: Self { self }
        var source: String { self == .all ? "all_reports" : "my_reports" }
    }

    @State private var scope = Scope.all
    @State private var reports: [Report] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selected: Report?

    var body: some View {
        List {
            Section {
                Picker("Show", selection: $scope) {
                    ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }

            Section {
                if let errorMessage {
                    Text(errorMessage).font(.footnote).foregroundStyle(.red)
                } else if reports.isEmpty && !isLoading {
                    Text(scope == .mine ? "You haven't filed any reports." : "No reports yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(reports) { report in
                    Button { selected = report } label: { row(report) }
                        .buttonStyle(.plain)
                }
            } header: {
                HStack {
                    Text("Incident").frame(maxWidth: .infinity, alignment: .leading)
                    Text("Location").frame(width: 100, alignment: .leading)
                    Text("Filed").frame(width: 64, alignment: .trailing)
                }
            }
        }
        .navigationTitle("Incident Tracker")
        .overlay { if isLoading && reports.isEmpty { ProgressView() } }
        .refreshable { await load() }
        .task(id: scope) { await load() }
        .fullScreenCover(item: $selected) { report in
            ReportDetailView(report: report) { selected = nil }
                .presentationBackground(.clear)
        }
    }

    private func row(_ report: Report) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(report.title ?? "Incident report").font(.subheadline.weight(.semibold))
                Text(report.description).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(report.placeName ?? "—")
                .font(.caption)
                .lineLimit(2)
                .frame(width: 100, alignment: .leading)
            Text(report.createdAt.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 64, alignment: .trailing)
        }
        .contentShape(.rect)
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let response = try await supabase.from(scope.source).select().order("created_at", ascending: false).limit(500).execute()
            reports = try JSONDecoder().decode([Report].self, from: response.data)
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't load reports: \(error.localizedDescription)"
        }
    }
}

/// UC Berkeley hotlines, escorts, and emergency services.
struct SafetyResourcesView: View {
    var body: some View {
        List {
            Section {
                link("Emergency", detail: "911", systemImage: "phone.fill", url: "tel://911", tint: .red)
                link("UCPD Emergency from a Cell Phone", detail: "(510) 642-3333", systemImage: "phone.fill", url: "tel://5106423333", tint: .red)
            } header: {
                Text("Emergency")
            } footer: {
                Text("Blue light phones on campus also connect straight to UCPD dispatch.")
            }

            Section("UCPD Resources") {
                link("UCPD Non-Emergency (24 hours)", detail: "(510) 642-6760", systemImage: "phone", url: "tel://5106426760")
                link("SafeWalk Escort", detail: "Dusk – 3 AM, last call 2:30 AM · (510) 642-WALK", systemImage: "figure.walk", url: "tel://5106429255")
                link("Night Safety Shuttle", detail: "7:30 PM – 3 AM · book in the Downtowner app", systemImage: "bus", url: "https://nightsafety.berkeley.edu/")
                link("Night Safety Services", detail: "nightsafety.berkeley.edu", systemImage: "moon.stars", url: "https://nightsafety.berkeley.edu/")
                link("Make a Report to UCPD", detail: "ucpd.berkeley.edu", systemImage: "doc.text", url: "https://ucpd.berkeley.edu/make-report")
                link("Resource Guide", detail: "Campus safety support", systemImage: "book", url: "https://supportal.berkeley.edu/topics/safety")
            }

            Section("Anonymous Tips") {
                link("CalTIP (text)", detail: "(510) 664-8477 · non-emergency crime", systemImage: "message", url: "sms:5106648477")
            }

            Section("City of Berkeley") {
                link("Berkeley Police Non-Emergency", detail: "(510) 981-5900", systemImage: "phone", url: "tel://5109815900")
            }
        }
        .navigationTitle("Safety Resources")
    }

    private func link(_ title: String, detail: String, systemImage: String, url: String, tint: Color = .accentColor) -> some View {
        Link(destination: URL(string: url)!) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: systemImage).foregroundStyle(tint)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Let Me Know").font(.title.bold())
                    Text("Students share what they see around campus as it happens, so everyone can see live incidents on the map and walk home on safer routes that avoid them, stay on lit streets, and keep to busier areas.")
                }
                .padding(.vertical, 6)
            }
            Section("Team 14 · UGBA 190D") {
                ForEach(["Arissa Zheng", "Arushi Desai", "Kevin Padilla", "Adonis Som", "Runn Kiriruangchai", "Sarah Elnahas"], id: \.self) {
                    Text($0)
                }
            }
            Section("Data") {
                LabeledContent("Streetlights", value: "City of Berkeley")
                LabeledContent("Population", value: "Student pings + simulated")
                LabeledContent("Routes", value: "Valhalla / OpenStreetMap")
            }
        }
        .navigationTitle("About Us")
    }
}
