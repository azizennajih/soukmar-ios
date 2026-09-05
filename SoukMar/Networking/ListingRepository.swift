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

    func getFavorites() async -> Result<[ListingDto], APIError> {
        do {
            let response: [ListingDto] = try await api.send(path: "favorites")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    /// Mirrors Android's getFavoriteIds(): there's no dedicated "is this
    /// favorited" endpoint, so fetch the full list and test membership.
    func getFavoriteIds() async -> Set<String> {
        guard case .success(let favorites) = await getFavorites() else { return [] }
        return Set(favorites.map(\.id))
    }

    func addFavorite(id: String) async -> Bool {
        do {
            let _: FavoriteRecordDto = try await api.send(path: "favorites/\(id)", method: "POST")
            return true
        } catch {
            return false
        }
    }

    func removeFavorite(id: String) async -> Bool {
        do {
            let _: SuccessDto = try await api.send(path: "favorites/\(id)", method: "DELETE")
            return true
        } catch {
            return false
        }
    }

    func createListing(_ body: ListingUpsertRequest) async -> Result<ListingDto, APIError> {
        do {
            let response: ListingDto = try await api.send(path: "listings", method: "POST", body: body)
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func updateListing(id: String, body: ListingUpsertRequest) async -> Result<ListingDto, APIError> {
        do {
            let response: ListingDto = try await api.send(path: "listings/\(id)", method: "PUT", body: body)
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func getMyListings() async -> Result<[ListingDto], APIError> {
        do {
            let response: [ListingDto] = try await api.send(path: "listings/user/mine")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func getViewStats(id: String) async -> Result<ViewStatsDto, APIError> {
        do {
            let response: ViewStatsDto = try await api.send(path: "listings/\(id)/view-stats")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func bump(id: String) async -> Result<ListingDto, APIError> {
        do {
            let response: ListingDto = try await api.send(path: "listings/\(id)/bump", method: "POST")
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func updateStatus(id: String, status: String) async -> Result<ListingDto, APIError> {
        do {
            let response: ListingDto = try await api.send(path: "listings/\(id)", method: "PUT", body: ListingStatusUpdateRequest(status: status))
            return .success(response)
        } catch let error as APIError {
            return .failure(error)
        } catch {
            return .failure(.network(error.localizedDescription))
        }
    }

    func deleteListing(id: String) async -> Bool {
        do {
            let _: SuccessDto = try await api.send(path: "listings/\(id)", method: "DELETE")
            return true
        } catch {
            return false
        }
    }
}
