import Foundation

/// Mirrors soukmar-backend's POST /listings/:id/boost-request body.
struct BoostRequestBody: Encodable {
    let tiers: [String]
}

/// Mirrors GET /listings/:id/boost-status.
struct BoostStatusDto: Codable {
    var boostSpotlightUntil: String? = nil
    var boostTopUntil: String? = nil
    var boostGlobalUntil: String? = nil
    var pendingRequest: BoostRequestDto? = nil
}

/// Mirrors a BoostRequest row (see soukmar-backend's BoostRequest model) —
/// returned by POST /listings/:id/boost-request and as `pendingRequest`
/// above, and (with listing/user refs attached) by GET /admin/boost-requests.
struct BoostRequestDto: Codable, Identifiable {
    let id: String
    let listingId: String
    let userId: String
    var tiers: [String] = []
    let totalPrice: Double
    let currency: String
    var status: String = "PENDING"
    var adminNote: String?
    let createdAt: String
    var resolvedAt: String?
    var user: ReportUserRefDto?
    var listing: BoostRequestListingRefDto?
}

struct BoostRequestListingRefDto: Codable {
    let id: String
    let title: String
    var images: [String] = []
    var status: String = "ACTIVE"
}

struct BoostRequestReviewRequest: Encodable {
    let status: String
    var adminNote: String?
}

/// Four original visibility-boost tiers — deliberately not a 1:1 copy of any
/// competitor's tier list (see soukmar/src/app/models/boost.model.ts, the
/// source of truth this mirrors, and soukmar-android's identical BoostDto.kt
/// port). Prices/durations are kept in sync by hand; the backend re-validates
/// and re-quotes on submit regardless.
enum BoostTierId: String, CaseIterable, Hashable {
    case bump, spotlight, top, global
}

struct BoostTier {
    let id: BoostTierId
    let priceMAD: Int
    let durationDays: Int?
}

let BOOST_TIERS: [BoostTier] = [
    BoostTier(id: .bump, priceMAD: 15, durationDays: nil),
    BoostTier(id: .spotlight, priceMAD: 39, durationDays: 7),
    BoostTier(id: .top, priceMAD: 59, durationDays: 7),
    BoostTier(id: .global, priceMAD: 89, durationDays: 10),
]

struct BoostQuote {
    let subtotal: Int
    let discountPercent: Int
    let total: Int
}

/// Mirrors quoteBoostPrice() in the web's boost.model.ts — 10% off when
/// combining 2+ tiers.
func quoteBoostPrice(_ tierIds: Set<BoostTierId>) -> BoostQuote {
    let byId = Dictionary(uniqueKeysWithValues: BOOST_TIERS.map { ($0.id, $0) })
    let subtotal = tierIds.reduce(0) { $0 + (byId[$1]?.priceMAD ?? 0) }
    let discountPercent = tierIds.count >= 2 ? 10 : 0
    let total = Int((Double(subtotal) * (1 - Double(discountPercent) / 100)).rounded())
    return BoostQuote(subtotal: subtotal, discountPercent: discountPercent, total: total)
}
