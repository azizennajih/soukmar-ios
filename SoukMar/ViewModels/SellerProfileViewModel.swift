import Foundation

/// Mirrors soukmar-android's SellerProfileViewModel — three parallel loads
/// (profile, seller's active listings, reviews received), profile load
/// failure is fatal (not-found state), the other two just stay empty.
@MainActor
final class SellerProfileViewModel: ObservableObject {
    @Published private(set) var loading = true
    @Published private(set) var notFound = false

    @Published private(set) var profile: SellerProfileDto?
    @Published private(set) var listings: [ListingDto] = []
    @Published private(set) var reviews: [ReviewWithDetailsDto] = []

    private let userRepository = UserRepository.shared
    private let reviewRepository = ReviewRepository.shared

    func load(sellerId: String) {
        Task {
            loading = true
            notFound = false
            switch await userRepository.getSellerProfile(id: sellerId) {
            case .success(let data):
                profile = data
            case .failure:
                notFound = true
            }
            if !notFound {
                async let listingsResult = userRepository.getSellerListings(id: sellerId)
                async let reviewsResult = reviewRepository.getForUser(userId: sellerId)
                if case .success(let data) = await listingsResult { listings = data }
                if case .success(let data) = await reviewsResult { reviews = data.reviews }
            }
            loading = false
        }
    }
}
