import Foundation

/// Mirrors soukmar-backend's POST /listings/:id/boost-request body.
struct BoostRequestBody: Encodable {
    let tiers: [String]
    /// Express consent that the service starts early and the withdrawal right ends on full performance (§ 356 (4) BGB).
    let withdrawalConsent: Bool
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
    let durationDays: Int?
}

let BOOST_TIERS: [BoostTier] = [
    BoostTier(id: .bump, durationDays: nil),
    BoostTier(id: .spotlight, durationDays: 7),
    BoostTier(id: .top, durationDays: 7),
    BoostTier(id: .global, durationDays: 10),
]

/// Boost prices per currency (kept in sync with the web's boost.model.ts and the backend's
/// lib/boosts.ts). A listing in a currency without its own price list is charged in EUR.
let BOOST_PRICES: [String: [BoostTierId: Double]] = [
    "MAD": [.bump: 15, .spotlight: 39, .top: 59, .global: 89],
    "EUR": [.bump: 1.49, .spotlight: 3.99, .top: 5.99, .global: 8.99],
    "USD": [.bump: 1.59, .spotlight: 4.29, .top: 6.49, .global: 9.99],
    "GBP": [.bump: 1.29, .spotlight: 3.49, .top: 4.99, .global: 7.49],
    "CHF": [.bump: 1.49, .spotlight: 3.99, .top: 5.99, .global: 8.99],
]

/// The currency a boost for a listing in `listingCurrency` is charged in.
func boostCurrency(_ listingCurrency: String?) -> String {
    if let c = listingCurrency, BOOST_PRICES[c] != nil { return c }
    return "EUR"
}

func tierPrice(_ id: BoostTierId, currency: String) -> Double {
    let prices = BOOST_PRICES[currency] ?? BOOST_PRICES["EUR"] ?? [:]
    return prices[id] ?? 0
}

struct BoostQuote {
    let subtotal: Double
    let discountPercent: Int
    let total: Double
}

/// Mirrors quoteBoostPrice() in the web's boost.model.ts — 10% off when combining 2+ tiers;
/// MAD in whole dirhams, other currencies with cents.
func quoteBoostPrice(_ tierIds: Set<BoostTierId>, currency: String = "MAD") -> BoostQuote {
    func cents(_ n: Double) -> Double { (n * 100).rounded() / 100 }
    let subtotal = cents(tierIds.reduce(0) { $0 + tierPrice($1, currency: currency) })
    let discountPercent = tierIds.count >= 2 ? 10 : 0
    let discounted = subtotal * (1 - Double(discountPercent) / 100)
    let total = currency == "MAD" ? discounted.rounded() : cents(discounted)
    return BoostQuote(subtotal: subtotal, discountPercent: discountPercent, total: total)
}
