import Foundation

struct SuccessDto: Codable {
    var success: Bool = true

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = try c.decodeIfPresent(Bool.self, forKey: .success) ?? true
    }
}

struct FavoriteRecordDto: Codable {
    var id: String?
    var userId: String?
    var listingId: String?
}
