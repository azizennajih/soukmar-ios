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

    func blockUser(id: String) async -> Result<BlockStatusDto, APIError> {
        do {
            let response: BlockStatusDto = try await api.send(path: "users/\(id)/block", method: "POST")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func unblockUser(id: String) async -> Result<BlockStatusDto, APIError> {
        do {
            let response: BlockStatusDto = try await api.send(path: "users/\(id)/block", method: "DELETE")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func followUser(id: String) async -> Result<FollowStatusDto, APIError> {
        do {
            let response: FollowStatusDto = try await api.send(path: "users/\(id)/follow", method: "POST")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func unfollowUser(id: String) async -> Result<FollowStatusDto, APIError> {
        do {
            let response: FollowStatusDto = try await api.send(path: "users/\(id)/follow", method: "DELETE")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func getFollowing() async -> Result<[FollowedUserDto], APIError> {
        do {
            let response: [FollowedUserDto] = try await api.send(path: "users/me/following")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }
}
