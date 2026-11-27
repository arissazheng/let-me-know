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

/// The student's campus hotlines, escorts, and emergency services, looked up when the campus was
/// first set up. Every number links back to the page it came from.
struct SafetyResourcesView: View {
    @Environment(CampusStore.self) private var campusStore

    var body: some View {
        List {
            if let campus = campusStore.campus, campus.status == .ready, !campus.resources.isEmpty {
                ForEach(campus.resources, id: \.self) { section in
                    Section {
                        ForEach(section.items, id: \.self) { row($0, emergency: section == campus.resources.first) }
                    } header: {
                        Text(section.title)
                    } footer: {
                        if let footer = section.footer { Text(footer) }
                    }
                }
                Section {
                } footer: {
                    Text("Found on \(campus.shortName ?? campus.domain)'s official pages when the campus was set up. Tap Source to check a number.")
                }
            } else {
                Section {
                    row(.init(label: "Emergency", detail: "911", phone: "911", url: nil, sourceURL: nil), emergency: true)
                } header: {
                    Text("Emergency")
                } footer: {
                    if campusStore.isSettingUp {
                        Label("Looking up your campus's safety resources. This takes about a minute the first time anyone from your school signs in.", systemImage: "magnifyingglass")
                    } else {
                        Text("We couldn't find your campus's safety resources yet.")
                    }
                }
            }
        }
        .navigationTitle("Safety Resources")
    }

    private func row(_ item: Campus.Resource, emergency: Bool) -> some View {
        HStack(alignment: .firstTextBaseline) {
            if let link = item.link {
                Link(destination: link) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.label).foregroundStyle(.primary)
                            Text(item.detail).font(.caption).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: icon(for: item)).foregroundStyle(emergency ? Color.red : Color.blue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
            }
            if let source = item.sourceURL.flatMap(URL.init(string:)) {
                Link("Source", destination: source)
                    .font(.caption)
                    .buttonStyle(.borderless)
            }
        }
    }

    private func icon(for item: Campus.Resource) -> String {
        if item.phone != nil { return "phone.fill" }
        if item.url?.hasPrefix("sms:") == true { return "message" }
        return "safari"
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
            Section("Why We Built This") {
                Text("Students regularly run into things like being followed, harassment, or aggressive behavior on their way around campus, and other students walking the same streets usually never hear about it. We built Let Me Know so students can warn each other the moment something happens and pick a safer way to get where they're going.")
                    .padding(.vertical, 4)
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
