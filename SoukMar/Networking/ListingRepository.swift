import Foundation

/// Mirrors soukmar-android's ListingRepository — same GET listings/{id}
/// endpoints and query-param contract as the backend's /api/listings route.
final class ListingRepository {
    static let shared = ListingRepository()
    private let api = APIClient.shared

    func getListings(params: [String: String]) async -> Result<ListingsResponseDto, APIError> {
        do {
            let response: ListingsResponseDto = try await api.send(path: "listings", query: params)
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func getListing(id: String) async -> Result<ListingDto, APIError> {
        do {
            let response: ListingDto = try await api.send(path: "listings/\(id)")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }
}
