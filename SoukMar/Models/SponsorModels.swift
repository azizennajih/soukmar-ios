import Foundation

/// Advertising/affiliate banner managed in the web admin area (GET banners).
struct SponsorBannerDto: Codable, Identifiable {
    let id: String
    let imageUrl: String
    let linkUrl: String
    var altText: String?
    var placement: String?
}
