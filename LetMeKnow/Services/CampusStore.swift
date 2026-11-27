import Foundation
import Observation
import Supabase

/// The signed-in student's campus: its name, center, police line, and safety resources. A campus
/// seen for the first time is looked up by the campus-info Edge Function; this waits for it.
@MainActor
@Observable
final class CampusStore {
    private(set) var campus: Campus?
    private(set) var errorMessage: String?

    var isSettingUp: Bool { campus.map { $0.status == .pending || $0.status == .generating } ?? true }

    func load(for email: String?) async {
        guard let domain = Campus.domain(of: email) else { return }
        var askedForLookup = false
        // A new campus takes about a minute; check every few seconds for up to five minutes.
        for _ in 0..<60 {
            do {
                let rows: [Campus] = try await supabase.from("campuses").select().eq("domain", value: domain).execute().value
                campus = rows.first
                errorMessage = nil
            } catch {
                errorMessage = "Couldn't load your campus: \(error.localizedDescription)"
            }
            if campus?.status == .ready { return }
            if campus?.status == .failed && askedForLookup { return }
            if !askedForLookup, campus?.status != .generating {
                askedForLookup = true
                _ = try? await supabase.functions.invoke("campus-info")
                continue
            }
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
        }
    }
}
