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
    @Published private(set) var followSubmitting = false

    private let userRepository = UserRepository.shared
    private let reviewRepository = ReviewRepository.shared

    /// Whether the follow button should show at all — mirrors web's
    /// `auth.currentUser()?.id !== profile.id`: hidden for both an own
    /// profile and a logged-out visitor (who sees a login link instead).
    var isLoggedIn: Bool { TokenStore.shared.isLoggedIn }
    var isOwnProfile: Bool { TokenStore.shared.cachedUser?.id == profile?.id }

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

    func toggleFollow() {
        guard let current = profile, !followSubmitting else { return }
        followSubmitting = true
        Task {
            let result = current.isFollowing
                ? await userRepository.unfollowUser(id: current.id)
                : await userRepository.followUser(id: current.id)
            if case .success(let status) = result {
                profile?.isFollowing = status.following
                profile?.followerCount = status.followerCount
            }
            followSubmitting = false
        }
    }
}
