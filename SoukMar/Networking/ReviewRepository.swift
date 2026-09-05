import Foundation

/// Mirrors soukmar-android's ReviewRepository — GET can-review, POST reviews.
final class ReviewRepository {
    static let shared = ReviewRepository()
    private let api = APIClient.shared

    func canReview(listingId: String) async -> Result<CanReviewResponse, APIError> {
        do {
            let response: CanReviewResponse = try await api.send(path: "reviews/can-review/\(listingId)")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func submitReview(listingId: String, revieweeId: String, rating: Int, comment: String?) async -> Result<ReviewDto, APIError> {
        do {
            let trimmedComment = comment?.trimmingCharacters(in: .whitespacesAndNewlines)
            let response: ReviewDto = try await api.send(
                path: "reviews", method: "POST",
                body: ReviewSubmitRequest(
                    listingId: listingId, revieweeId: revieweeId, rating: rating,
                    comment: (trimmedComment?.isEmpty ?? true) ? nil : trimmedComment
                )
            )
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func getForUser(userId: String) async -> Result<ReviewsForUserResponse, APIError> {
        do {
            let response: ReviewsForUserResponse = try await api.send(path: "reviews/user/\(userId)")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }
}
