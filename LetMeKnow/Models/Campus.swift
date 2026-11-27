import CoreLocation
import Foundation

/// A school using Let Me Know, from the `campuses` table (006_campuses.sql). Set up automatically
/// the first time one of its students signs in.
struct Campus: Decodable, Equatable {
    struct Resource: Decodable, Equatable, Hashable {
        let label: String
        let detail: String
        let phone: String?
        let url: String?
        let sourceURL: String?

        enum CodingKeys: String, CodingKey {
            case label, detail, phone, url
            case sourceURL = "source_url"
        }

        /// What tapping the row opens: a call, a text, or a web page.
        var link: URL? {
            if let phone { return URL(string: "tel://\(phone)") }
            return url.flatMap(URL.init(string:))
        }
    }

    struct Section: Decodable, Equatable, Hashable {
        let title: String
        let footer: String?
        let items: [Resource]
    }

    enum Status: String, Decodable { case pending, generating, ready, failed }

    let domain: String
    let name: String?
    let shortName: String?
    let lat: Double?
    let lng: Double?
    let policeName: String?
    let policePhone: String?
    let resources: [Section]
    let status: Status

    enum CodingKeys: String, CodingKey {
        case domain, name, lat, lng, resources, status
        case shortName = "short_name"
        case policeName = "police_name"
        case policePhone = "police_phone"
    }

    var center: CLLocationCoordinate2D? {
        guard let lat, let lng else { return nil }
        return .init(latitude: lat, longitude: lng)
    }

    /// jane@g.ucla.edu → ucla.edu (same rule as public.campus_of).
    static func domain(of email: String?) -> String? {
        guard let email = email?.lowercased(),
              let match = email.firstMatch(of: /([a-z0-9-]+\.edu)$/)
        else { return nil }
        return String(match.1)
    }
}
