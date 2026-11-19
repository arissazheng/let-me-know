import CoreLocation
import Foundation

/// A student-filed safety report (F3, F4).
struct Report: Identifiable, Decodable, Equatable {
    let id: UUID
    let lat: Double
    let lng: Double
    let description: String
    let mediaURL: URL?
    let mediaType: MediaType?
    let createdAt: Date
    let isDemo: Bool

    enum MediaType: String, Codable {
        case image, video
    }

    var coordinate: CLLocationCoordinate2D { .init(latitude: lat, longitude: lng) }

    enum CodingKeys: String, CodingKey {
        case id, lat, lng, description
        case mediaURL = "media_url"
        case mediaType = "media_type"
        case createdAt = "created_at"
        case isDemo = "is_demo"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        lat = try c.decode(Double.self, forKey: .lat)
        lng = try c.decode(Double.self, forKey: .lng)
        description = try c.decode(String.self, forKey: .description)
        mediaURL = try c.decodeIfPresent(String.self, forKey: .mediaURL).flatMap(URL.init(string:))
        mediaType = try c.decodeIfPresent(MediaType.self, forKey: .mediaType)
        isDemo = try c.decodeIfPresent(Bool.self, forKey: .isDemo) ?? false
        // PostgREST and Realtime format timestamps slightly differently, so parse leniently.
        let raw = try c.decode(String.self, forKey: .createdAt)
        guard let date = Report.parseTimestamp(raw) else {
            throw DecodingError.dataCorruptedError(forKey: .createdAt, in: c, debugDescription: "Bad timestamp \(raw)")
        }
        createdAt = date
    }

    static func parseTimestamp(_ raw: String) -> Date? {
        var text = raw.replacingOccurrences(of: " ", with: "T")
        // Postgres may emit "+00" offsets; ISO 8601 wants "+00:00".
        if let range = text.range(of: #"[+-]\d{2}$"#, options: .regularExpression) {
            text.replaceSubrange(range, with: text[range] + ":00")
        }
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return withFraction.date(from: text) ?? plain.date(from: text)
    }
}

struct NewReport: Encodable {
    let lat: Double
    let lng: Double
    let description: String
    let mediaURL: String?
    let mediaType: Report.MediaType?

    enum CodingKeys: String, CodingKey {
        case lat, lng, description
        case mediaURL = "media_url"
        case mediaType = "media_type"
    }
}
