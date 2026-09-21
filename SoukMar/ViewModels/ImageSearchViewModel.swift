import Foundation

/// Mirrors Web's ImageSearchComponent — pick a photo, upload it to the
/// dedicated POST /api/listings/search-by-image endpoint (single `image`
/// field, no auth, server-side perceptual-hash matching, no paid vision
/// API), show a loading state, then either a results grid or an empty
/// state. No pagination — the backend already caps results server-side.
@MainActor
final class ImageSearchViewModel: ObservableObject {
    @Published private(set) var results: [ListingDto] = []
    @Published private(set) var loading = false
    @Published private(set) var searched = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var previewData: Data?

    private let listingRepository = ListingRepository.shared

    func runSearch(data: Data, filename: String = "photo.jpg", mimeType: String = "image/jpeg") {
        previewData = data
        loading = true
        searched = true
        errorMessage = nil
        results = []
        Task {
            switch await listingRepository.searchByImage(data: data, filename: filename, mimeType: mimeType) {
            case .success(let listings):
                results = listings
            case .failure:
                errorMessage = "La recherche a échoué. Veuillez réessayer."
            }
            loading = false
        }
    }
}
