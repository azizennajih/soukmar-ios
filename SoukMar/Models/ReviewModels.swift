import Foundation

/// Mirrors soukmar-backend's GET /api/reviews/can-review/:listingId.
struct CanReviewResponse: Codable {
    var canReview: Bool = false
    var revieweeId: String?
    var alreadyReviewed: Bool = false

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        canReview = try c.decodeIfPresent(Bool.self, forKey: .canReview) ?? false
        revieweeId = try c.decodeIfPresent(String.self, forKey: .revieweeId)
        alreadyReviewed = try c.decodeIfPresent(Bool.self, forKey: .alreadyReviewed) ?? false
    }
}

struct ReviewSubmitRequest: Encodable {
    let listingId: String
    let revieweeId: String
    let rating: Int
    let comment: String?
}

struct ReviewDto: Codable {
    let id: String
    let rating: Int
    var comment: String?
}

struct ReviewAuthorDto: Codable {
    let id: String
    let name: String
    var image: String?
}

struct ReviewListingRefDto: Codable {
    let id: String
    let title: String
}

/// Mirrors soukmar-backend's GET /api/reviews/user/:userId — a review
/// received by that user, with the reviewer and listing it was left on.
struct ReviewWithDetailsDto: Codable, Identifiable {
    let id: String
    let listingId: String
    let reviewerId: String
    let revieweeId: String
    let rating: Int
    var comment: String?
    let createdAt: String
    var reviewer: ReviewAuthorDto?
    var listing: ReviewListingRefDto?
}

struct ReviewsForUserResponse: Codable {
    var reviews: [ReviewWithDetailsDto] = []
    var avgRating: Double?
    var count: Int = 0

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        reviews = try c.decodeIfPresent([ReviewWithDetailsDto].self, forKey: .reviews) ?? []
        avgRating = try c.decodeIfPresent(Double.self, forKey: .avgRating)
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
    }
}

/// Mirrors soukmar-backend's GET /api/users/:id/profile.
struct SellerProfileDto: Codable {
    let id: String
    let name: String
    var city: String?
    var image: String?
    let createdAt: String
    var avgRating: Double?
    var reviewCount: Int = 0
    var activeListingsCount: Int = 0
    var avgResponseHours: Double?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        city = try c.decodeIfPresent(String.self, forKey: .city)
        image = try c.decodeIfPresent(String.self, forKey: .image)
        createdAt = try c.decode(String.self, forKey: .createdAt)
        avgRating = try c.decodeIfPresent(Double.self, forKey: .avgRating)
        reviewCount = try c.decodeIfPresent(Int.self, forKey: .reviewCount) ?? 0
        activeListingsCount = try c.decodeIfPresent(Int.self, forKey: .activeListingsCount) ?? 0
        avgResponseHours = try c.decodeIfPresent(Double.self, forKey: .avgResponseHours)
    }
}
