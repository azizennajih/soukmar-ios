import Foundation

/// Mirrors soukmar-android's ListingDetailViewModel. Chat entry ("Contacter
/// le vendeur") is intentionally left out — chat itself is a later iOS phase
/// (Android Phase 5 equivalent), same deferred-scope approach as Phase 2's
/// listing-tap-does-nothing gap it now closes.
@MainActor
final class ListingDetailViewModel: ObservableObject {
    @Published private(set) var listing: ListingDto?
    @Published private(set) var loading = true
    @Published private(set) var loadError = false

    @Published private(set) var isLoggedIn = false

    @Published private(set) var favorited = false
    @Published private(set) var favLoading = false

    @Published private(set) var canReview = false
    private var revieweeId: String?
    @Published var showReviewForm = false
    @Published var reviewRating = 5
    @Published var reviewComment = ""
    @Published private(set) var reviewSubmitting = false
    @Published private(set) var reviewSubmitted = false

    @Published var reportOpen = false
    @Published var reportReason = ""
    @Published private(set) var reportSubmitting = false
    @Published private(set) var reportSubmitted = false
    @Published private(set) var reportError: String?

    private let listingRepository = ListingRepository.shared
    private let reviewRepository = ReviewRepository.shared
    private let reportRepository = ReportRepository.shared

    var priceComparisonPct: Int? {
        guard let price = listing?.price, let avg = listing?.avgPrice, avg != 0 else { return nil }
        return Int(((price - avg) / avg * 100).rounded())
    }

    func load(id: String) {
        Task {
            loading = true
            loadError = false
            isLoggedIn = TokenStore.shared.isLoggedIn
            switch await listingRepository.getListing(id: id) {
            case .success(let data):
                listing = data
                if isLoggedIn {
                    favorited = await listingRepository.getFavoriteIds().contains(id)
                    await checkCanReview(listingId: id)
                }
            case .failure:
                loadError = true
            }
            loading = false
        }
    }

    private func checkCanReview(listingId: String) async {
        switch await reviewRepository.canReview(listingId: listingId) {
        case .success(let data):
            canReview = data.canReview
            revieweeId = data.revieweeId
        case .failure:
            break // review prompt is optional, silently skip
        }
    }

    func toggleFavorite() {
        guard let id = listing?.id, !favLoading else { return }
        let wasFav = favorited
        favorited = !wasFav
        favLoading = true
        Task {
            let ok = wasFav ? await listingRepository.removeFavorite(id: id) : await listingRepository.addFavorite(id: id)
            if !ok { favorited = wasFav }
            favLoading = false
        }
    }

    func submitReview() {
        guard let id = listing?.id, let revieweeId, !reviewSubmitting else { return }
        reviewSubmitting = true
        Task {
            switch await reviewRepository.submitReview(listingId: id, revieweeId: revieweeId, rating: reviewRating, comment: reviewComment) {
            case .success:
                reviewSubmitted = true
                showReviewForm = false
                canReview = false
            case .failure:
                break // leave the form open so the user can retry
            }
            reviewSubmitting = false
        }
    }

    func submitReport() {
        guard let reportedId = listing?.userId else { return }
        guard reportReason.trimmingCharacters(in: .whitespacesAndNewlines).count >= 10 else {
            reportError = "Merci de décrire la raison en au moins 10 caractères."
            return
        }
        reportSubmitting = true
        reportError = nil
        Task {
            switch await reportRepository.submit(reportedId: reportedId, listingId: listing?.id, reason: reportReason.trimmingCharacters(in: .whitespacesAndNewlines)) {
            case .success:
                reportSubmitting = false
                reportSubmitted = true
                reportOpen = false
            case .failure(let error):
                reportSubmitting = false
                reportError = Self.message(for: error)
            }
        }
    }

    func cancelReport() {
        reportOpen = false
        reportError = nil
    }

    private static func message(for error: APIError) -> String {
        switch error {
        case .server(let message, _): return message
        case .network(let message): return message
        case .decoding: return "Une erreur est survenue."
        }
    }
}
