import Foundation

/// One suggestion from GET /api/places (a town or village of a country, GeoNames data).
/// `admin1` is its region, shown beside the name to tell apart villages that share a name.
struct PlaceHit: Decodable, Hashable, Identifiable {
    let name: String
    let admin1: String?
    let population: Int

    var id: String { name + "|" + (admin1 ?? "") }
}
