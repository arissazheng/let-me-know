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

    /// F4: uploads any photos/videos, looks up the street, then files the report.
    func submit(title: String, description: String, at coordinate: CLLocationCoordinate2D, media: [PickedMedia]) async throws {
        let bucket = supabase.storage.from("report-media")
        var uploaded: [Report.MediaItem] = []
        for item in media {
            let path = "\(UUID().uuidString).\(item.fileExtension)"
            _ = try await bucket.upload(path, data: item.data, options: FileOptions(contentType: item.contentType))
            uploaded.append(.init(url: try bucket.getPublicURL(path: path), type: item.type))
        }
        let row = NewReport(
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            title: title.isEmpty ? nil : title,
            description: description,
            media: uploaded,
            mediaURL: uploaded.first?.url.absoluteString,
            mediaType: uploaded.first?.type,
            placeName: await Self.streetName(at: coordinate)
        )
        try await supabase.from("reports").insert(row).execute()
    }

    /// The street at a point, from OpenStreetMap (Nominatim); nil if the lookup fails.
    private static func streetName(at c: CLLocationCoordinate2D) async -> String? {
        var request = URLRequest(url: URL(string: "https://nominatim.openstreetmap.org/reverse?format=jsonv2&zoom=17&lat=\(c.latitude)&lon=\(c.longitude)")!)
        request.setValue("LetMeKnow/0.2 (UC Berkeley class prototype)", forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let address = json["address"] as? [String: Any]
        else { return nil }
        return (address["road"] ?? address["pedestrian"] ?? address["footway"]) as? String
    }
}

struct PickedMedia {
    let data: Data
    let type: Report.MediaType
    let fileExtension: String
    let contentType: String
}
