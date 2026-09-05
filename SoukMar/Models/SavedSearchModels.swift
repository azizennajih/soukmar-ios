import Foundation

/// Mirrors soukmar-backend's SavedSearch model / /api/saved-searches routes.
/// Specific typed columns, not a serialized filter blob — except `attrs`,
/// which stores the SELECT/BOOLEAN EAV filter selections only (code -> list
/// of selected option values). NUMBER attribute ranges aren't persisted,
/// matching the web app's saveSearch() which skips _min/_max range keys.
struct SavedSearchDto: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    var category: String?
    var subcategoryId: String?
    var q: String?
    var city: String?
    var minPrice: Double?
    var maxPrice: Double?
    var condition: String?
    var attrs: [String: [String]]?
    let createdAt: String
}

struct SavedSearchCreateRequest: Encodable {
    let name: String
    var category: String?
    var subcategoryId: String?
    var q: String?
    var city: String?
    var minPrice: Double?
    var maxPrice: Double?
    var condition: String?
    var attrs: [String: [String]]?
}
