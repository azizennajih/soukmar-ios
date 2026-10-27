import Foundation

/// Admin dashboard data (web: AdminComponent; Android: AdminDashboardDto.kt) — users, activity feed,
/// visitor analytics, security log. Fields the server may omit are optional.
struct AdminUserCountDto: Codable {
    var listings: Int?
}

struct AdminUserDto: Codable, Identifiable {
    let id: String
    var name: String?
    var email: String?
    var role: String
    var city: String?
    var country: String?
    var phone: String?
    var createdAt: String?
    var listingCount: AdminUserCountDto?

    enum CodingKeys: String, CodingKey {
        case id, name, email, role, city, country, phone, createdAt
        case listingCount = "_count"
    }
}

struct AdminUserRoleRequest: Codable {
    let role: String
}

struct AdminActivityDto: Codable, Identifiable {
    let type: String
    var at: String?
    var country: String?
    var title: String?
    var detail: String?
    var amount: Double?
    var currency: String?
    var status: String?

    var id: String { "\(type)-\(at ?? "")-\(title ?? "")" }
}

struct AdminCountryCountDto: Codable {
    let country: String
    var count: Int?
    var visitors: Int?
}

struct AdminActiveNowDto: Codable {
    var total: Int?
    var byCountry: [AdminCountryCountDto]?
}

struct AdminDailyDto: Codable {
    let date: String
    var visitors: Int?
}

struct AdminAnalyticsDto: Codable {
    var days: Int?
    var activeNow: AdminActiveNowDto?
    var today: AdminActiveNowDto?
    var daily: [AdminDailyDto]?
    var byCountry: [AdminCountryCountDto]?
}

struct SecurityEventUserDto: Codable {
    var id: String?
    var name: String?
    var email: String?
}

struct SecurityEventDto: Codable, Identifiable {
    let id: String
    let type: String
    var severity: String?
    var ip: String?
    var userId: String?
    var detail: String?
    var createdAt: String?
    var user: SecurityEventUserDto?
}

struct ListingPremiumUpdateRequest: Codable {
    let isPremium: Bool
}

