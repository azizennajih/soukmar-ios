import Foundation

/// Mirrors soukmar-android's FavorisViewModel.
@MainActor
final class FavorisViewModel: ObservableObject {
    @Published private(set) var listings: [ListingDto] = []
    @Published private(set) var loading = true

    private let listingRepository = ListingRepository.shared

    func load() {
        Task {
            loading = true
            switch await listingRepository.getFavorites() {
            case .success(let data):
                listings = data
            case .failure:
                break // empty list is a fine fallback here
            }
            loading = false
        }
    }

    /// Optimistic removal, mirroring the heart-toggle pattern already used
    /// on ListingDetailView — revert if the backend call fails.
    func removeFavorite(_ id: String) {
        let previous = listings
        listings.removeAll { $0.id == id }
        Task {
            if !(await listingRepository.removeFavorite(id: id)) {
                listings = previous
            }
        }
    }
}
