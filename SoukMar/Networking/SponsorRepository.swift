import Foundation

/// Advertising/affiliate banners (mirrors the web's SponsorService and Android's SponsorRepository). The app only
/// has room for the INLINE placement: between listings and on the home screen. Failures never matter to the
/// visitor: no banners then.
@MainActor
final class SponsorRepository {
    static let shared = SponsorRepository()
    private let api = APIClient.shared
    private var cache: [String: [SponsorBannerDto]] = [:]

    func inlineBanners(country: String) async -> [SponsorBannerDto] {
        if let cached = cache[country] { return cached }
        do {
            let banners: [SponsorBannerDto] = try await api.send(path: "banners", query: ["placement": "INLINE", "country": country])
            cache[country] = banners
            return banners
        } catch {
            return []
        }
    }

    /// Counts a click (an aggregate number only); a lost count is harmless.
    func click(id: String) {
        Task {
            let _: SponsorClickResponse? = try? await api.send(path: "banners/\(id)/click", method: "POST", body: SponsorEmptyBody())
        }
    }
}

private struct SponsorEmptyBody: Encodable {}
private struct SponsorClickResponse: Decodable {}
