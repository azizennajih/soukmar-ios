import Foundation

/// Mirrors soukmar-android's UserRepository — soukmar-backend's /api/users
/// routes, public seller-profile data.
final class UserRepository {
    static let shared = UserRepository()
    private let api = APIClient.shared

    func getSellerProfile(id: String) async -> Result<SellerProfileDto, APIError> {
        do {
            let response: SellerProfileDto = try await api.send(path: "users/\(id)/profile")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func getSellerListings(id: String) async -> Result<[ListingDto], APIError> {
        do {
            let response: [ListingDto] = try await api.send(path: "users/\(id)/listings")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }
}
