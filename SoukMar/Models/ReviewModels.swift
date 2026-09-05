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
