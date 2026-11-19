import CoreLocation
import Foundation
import Observation
import Supabase

/// Live reports from the last 24 hours (F3), filing new ones (F4), and realtime inserts (F8).
@MainActor
@Observable
final class ReportsStore {
    private(set) var reports: [Report] = []
    /// The most recent report another student filed while the app was open.
    private(set) var latestLiveReport: Report?
    var errorMessage: String?

    private var channel: RealtimeChannelV2?

    func load() async {
        do {
            let response = try await supabase.from("live_reports").select().execute()
            reports = try JSONDecoder().decode([Report].self, from: response.data)
        } catch {
            errorMessage = "Couldn't load reports: \(error.localizedDescription)"
        }
    }

    func listen() async {
        let channel = supabase.channel("reports")
        self.channel = channel
        let inserts = channel.postgresChange(InsertAction.self, schema: "public", table: "reports")
        do {
            try await channel.subscribeWithError()
        } catch {
            errorMessage = "Live updates unavailable: \(error.localizedDescription)"
            return
        }
        for await insert in inserts {
            guard let report = try? insert.decodeRecord(as: Report.self, decoder: JSONDecoder()) else { continue }
            if !reports.contains(where: { $0.id == report.id }) {
                reports.append(report)
            }
            latestLiveReport = report
        }
    }

    func submit(description: String, at coordinate: CLLocationCoordinate2D, media: PickedMedia?) async throws {
        var mediaURL: String?
        if let media {
            let path = "\(UUID().uuidString).\(media.fileExtension)"
            let bucket = supabase.storage.from("report-media")
            _ = try await bucket.upload(path, data: media.data, options: FileOptions(contentType: media.contentType))
            mediaURL = try bucket.getPublicURL(path: path).absoluteString
        }
        let row = NewReport(
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            description: description,
            mediaURL: mediaURL,
            mediaType: media?.type
        )
        try await supabase.from("reports").insert(row).execute()
    }
}

struct PickedMedia {
    let data: Data
    let type: Report.MediaType
    let fileExtension: String
    let contentType: String
}
